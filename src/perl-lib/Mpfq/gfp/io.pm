package Mpfq::gfp::io;

use strict;
use warnings;

sub code_for_asprint {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $w = $opt->{'w'};
    my $proto = 'function(k,pstr,x)';
    my $code = <<EOF;
int i, n;
// allocate enough room for base 2 conversion.
*pstr = (char *)malloc(($n*$w+1)*sizeof(char));
if (*pstr == NULL)
    MALLOC_FAILED();
n = mpn_get_str((unsigned char*)(*pstr), k->io_base, (mp_limb_t *) x, $n);
for (i = 0; i < n; ++i)
    (*pstr)[i] += '0';
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
EOF
    return [ $proto, $code ];
}

sub code_for_sscan {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $w = $opt->{'w'};
    my $proto = 'function(k,z,str)';
    my $code = <<EOF;
mpz_t zz;
mpz_init(zz);
if (gmp_sscanf(str, "%Zd", zz) != 1) {
    mpz_clear(zz);
    return 0;
}
@!set_mpz(k, z, zz);
mpz_clear(zz);
return 1;
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
        start=1;
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

1;
