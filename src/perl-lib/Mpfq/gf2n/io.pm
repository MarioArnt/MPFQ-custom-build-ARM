package Mpfq::gf2n::io;
use strict;
use warnings;

use Mpfq::engine::utils qw(
    ceildiv
);

sub code_for_asprint {
    my $opt = $_[0];
    my $n = $opt->{'n'};
    my $w = $opt->{'w'};
    my $eltwidth = ceildiv $n, $w;
    my $proto = 'function(k,pstr,x)';
    my $code = <<EOF;
int type = k->io_type;
int i, n; 

// Numerical io.
if (type <= 16) {
    // allocate enough room for base 2 conversion.
    *pstr = (char *)malloc(($n+1)*sizeof(char));
    if (*pstr == NULL)
        MALLOC_FAILED();

    mp_limb_t tmp[$eltwidth + 1];
    for (i = 0; i < $eltwidth; ++i)
        tmp[i] = x[i];

    // mpn_get_str() needs a non-zero most significant limb
    int msl = $eltwidth - 1;
    while ((msl > 0) && (tmp[msl] == 0))
        msl--;
    msl++;
    if ((msl == 1) && (tmp[0] == 0)) {
        (*pstr)[0] = '0';
        (*pstr)[1] = '\\0';
        return;
    }
    n = mpn_get_str((unsigned char*)(*pstr), type, tmp, msl);
    for (i = 0; i < n; ++i) {
        char c = (*pstr)[i] + '0';
        if (c > '9')
            c = c-'0'+'a'-10;
        (*pstr)[i] = c;
    }
    (*pstr)[n] = '\\0';

    // Remove leading 0s
    int shift = 0;
    while (((*pstr)[shift] == '0') && ((*pstr)[shift+1] != '\\0')) 
        shift++;
    if (shift>0) {
        i = 0;
        while ((*pstr)[i+shift] != '\\0') {
            (*pstr)[i] = (*pstr)[i+shift];
            i++;
        }
        (*pstr)[i] = '\\0';
    }

    // Return '0' instead of empty string for zero element
    if ((*pstr)[0] == '\\0') {
        (*pstr)[0] = '0';
        (*pstr)[1] = '\\0';
    }
} 
// Polynomial io.
else {
    char c = (char)type;
    // allocate (more than) enough room for polynomial conversion.
    // Warning: this is for exponent that fit in 3 digits
    *pstr = (char *)malloc((8*$n+1)*sizeof(char));
    if (*pstr == NULL)
        MALLOC_FAILED();
    {
        unsigned int j;
        int sth = 0;
        char *ptr = *pstr;
        for(j = 0 ; j < $n ; j++) {
            if (x[j/$w] >> (j % $w) & 1UL) {
            	if (sth) {
                    *ptr++ = ' ';
                    *ptr++ = '+';
                    *ptr++ = ' ';
                }
            	sth = 1;
            	if (j == 0) {
                    *ptr++ = '1';      
            	} else if (j == 1) {
                    *ptr++ = c;      
            	} else {
                    int ret = sprintf(ptr,"\%c^\%d",c,j);
                    ptr += ret;
            	}
            }
        }
        if (!sth) {
            *ptr++ = '0';
        }
        *ptr = '\\0';
    }
}
EOF
    return [ $proto, $code ];
}

sub code_for_sscan {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $w = $opt->{'w'};
    my $eltwidth = ceildiv $n, $w;
    my $proto = 'function(k,z,str)';
    my $code = <<EOF;
if (k->io_type <= 16) {
    char *tmp;
    int len = strlen(str);
    tmp = (char *)malloc(len+1);
    int i;
    for (i = 0; i < len; ++i) {
        if (str[i] > '9')
            tmp[i] = str[i] + 10 - 'a';
        else 
            tmp[i] = str[i] - '0';
    }
    mp_limb_t *zz;
    // Allocate one limb per byte... very conservative.
    zz = (mp_limb_t *)malloc(len*sizeof(mp_limb_t));
    int ret = mpn_set_str(zz, tmp, len, k->io_type);
    free(tmp);
    if (ret > $eltwidth) {
        free(zz);
        return 0;
    }
    for (i = 0; i < ret; ++i)
        z[i] = zz[i];
    for (i = ret; i < $eltwidth; ++i)
        z[i] = 0;
    free(zz);
    return 1;
} else {
    fprintf(stderr, "Polynomial io not implemented for reading\\n");
    return 0;
}
EOF
    return [ $proto, $code ];
}

sub code_for_fscan {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $w = $opt->{'w'};
    my $proto = 'function(k,file,z)';
    my $code = <<EOF;
char *tmp;
int allocated, len=0;
int c, start=0;
allocated=100;
tmp = (char *)malloc(allocated*sizeof(char));
if (!tmp)
    MALLOC_FAILED();
for(;;) {
    c = fgetc(file);
    if (c==EOF)
        break;
    if (isspace((int)(unsigned char)c)) {
        if (start==0)
            continue;
        else
            break;
    } else {
        if (len==allocated) {
            allocated+=100;
            tmp = (char*)realloc(tmp, allocated*sizeof(char));
        }
        tmp[len]=c;
        len++;
    }
}
if (len==allocated) {
    allocated+=1;
    tmp = (char*)realloc(tmp, allocated*sizeof(char));
}
tmp[len]='\\0';
int ret=@!sscan(k,z,tmp);
free(tmp);
return ret;
EOF
    return [ $proto, $code ];
}

sub code_for_scan {
    return [ 'macro(k,x)', '@!fscan(k,stdout,x)' ];
}



sub init_handler {
    my ($opt) = @_;

    for my $t (qw/n w/) {
	return -1 unless exists $opt->{$t};
    }
    return {};
}

1;
# vim:set sw=4 sta et:
