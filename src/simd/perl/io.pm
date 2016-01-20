package io;

use strict;
use warnings;

sub code_for_asprint {
    my $code = <<EOF;
    const uint64_t * y = x;
    const unsigned int stride = @!vec_elt_stride(K,1)/sizeof(uint64_t);
    *ps = malloc(stride * 16 + 1);
    if (!*ps) MALLOC_FAILED();
    for(unsigned int i = 0 ; i < stride ; i++) {
        snprintf((*ps) + i * 16, 17, "%" PRIx64, y[i]);
    }
EOF
    return [ 'function(K!, ps, x)', $code ];
}

sub code_for_fprint {
    my $proto = 'function(k,file,x)';
    my $code = <<EOF;
char *str;
@!asprint(k,&str,x);
fprintf(file,"%s",str);
free(str);
EOF
    return [ $proto, $code ];
}

sub code_for_print {
    return [ 'macro(k,x)', '@!fprint(k,stdout,x)' ];
}

sub code_for_sscan {
    my $opt = shift @_;
    my $proto = 'function(k!,z,str)';
    my $code = <<EOF;
    char tmp[17];
    uint64_t * y = z;
    const unsigned int stride = @!vec_elt_stride(K,1)/sizeof(uint64_t);
    assert(strlen(str) >= 1 * 16);
    int r = 0;
    for(unsigned int i = 0 ; i < stride ; i++) {
        memcpy(tmp, str + i * 16, 16);
        tmp[16]=0;
        if (sscanf(tmp, "%" SCNx64, &(y[i])) == 1) {
            r+=16;
        } else {
            return r;
        }
    }
    return r;
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
    return [ 'macro(k,x)', '@!fscan(k,stdin,x)' ];
}

sub init_handler {
    return { 'c:includes' => [qw/<inttypes.h>/]};
}

1;
