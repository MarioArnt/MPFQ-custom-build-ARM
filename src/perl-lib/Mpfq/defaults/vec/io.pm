package Mpfq::defaults::vec::io;

use strict;
use warnings;

sub code_for_vec_asprint {
    my $opt = shift @_;
    my $proto = 'function(K!,pstr,w,n)';
    my $code = <<EOF;
if (n == 0) {
    *pstr = (char *)malloc(4*sizeof(char));
    sprintf(*pstr, "[ ]");
    return;
}
int alloc = 100;
int len = 0;
*pstr = (char *)malloc(alloc*sizeof(char));
char *str = *pstr;
*str++ = '[';
*str++ = ' ';
len = 2;
unsigned int i;
for(i = 0; i < n; i+=1) {
    if (i) {
        (*pstr)[len++] = ',';
        (*pstr)[len++] = ' ';
    }
    char *tmp;
    @!asprint(K, &tmp, w[i]);
    int ltmp = strlen(tmp);
    if (len+ltmp+4 > alloc) {
        alloc = len+ltmp+100;
        *pstr = (char *)realloc(*pstr, alloc*sizeof(char));
    }
    strncpy(*pstr+len, tmp, ltmp+4);
    len += ltmp;
    free(tmp);
}
(*pstr)[len++] = ' ';
(*pstr)[len++] = ']';
(*pstr)[len] = '\\0';
EOF
    return [ $proto, $code ];
}

sub code_for_vec_fprint {
    my $opt = shift @_; 
    my $n = $opt->{'n'};
    my $w = $opt->{'w'};
    my $proto = 'function(K!,file,w,n)';
    my $code = <<EOF;
char *str;
@!vec_asprint(K,&str,w,n);
fprintf(file,"%s",str);
free(str);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_print {
    my $proto = 'function(K!,w,n)';
    my $code = <<EOF;
@!vec_fprint(K,stdout,w,n);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_sscan {
    my $proto = 'function(K!,w,n,str)';
    my $code = <<EOF;
// start with a clean vector
@!vec_reinit(K, w, *n, 0);
*n = 0;
while (isspace((int)(unsigned char)str[0]))
    str++;
if (str[0] != '[')
    return 0;
str++;
if (str[0] != ' ')
    return 0;
str++;
if (str[0] == ']') {
    return 1;
}
unsigned int i = 0;
for (;;) {
    if (*n < i+1) {
        @!vec_reinit(K, w, *n, i+1);
        *n = i+1;
    }
    int ret;
    ret = @!sscan(K, (*w)[i], str);
    if (!ret) {
        return 0;
    }
    i++;
    while (isdigit((int)(unsigned char)str[0]))
        str++;
    while (isspace((int)(unsigned char)str[0]))
        str++;
    if (str[0] == ']')
        break;
    if (str[0] != ',')
        return 0;
    str++;
    while (isspace((int)(unsigned char)str[0]))
        str++;
}
return 1;
EOF
    return [ $proto, $code ];
}

sub code_for_vec_fscan {
    my $proto = 'function(K!,file,w,n)';
    my $code = <<EOF;
char *tmp;
int c;
int allocated, len=0;
allocated=100;
tmp = (char *)malloc(allocated*sizeof(char));
if (!tmp)
    MALLOC_FAILED();
for(;;) {
    c = fgetc(file);
    if (c==EOF)
        return 0;
    if (len==allocated) {
        allocated+=100;
        tmp = (char*)realloc(tmp, allocated*sizeof(char));
    }
    tmp[len]=c;
    len++;
    if (c==']')
        break;
}
if (len==allocated) {
    allocated+=1;
    tmp = (char*)realloc(tmp, allocated*sizeof(char));
}
tmp[len]='\\0';
int ret=@!vec_sscan(K,w,n,tmp);
free(tmp);
return ret;
EOF
    return [ $proto, $code ];
}

sub code_for_vec_scan {
    return [ 'macro(K,w,n)', '@!vec_fscan(K,stdout,w,n)' ];
}

1;
