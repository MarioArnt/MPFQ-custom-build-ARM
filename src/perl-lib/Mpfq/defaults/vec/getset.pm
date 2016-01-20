package Mpfq::defaults::vec::getset;

use strict;
use warnings;

sub code_for_vec_setcoef {
    my $proto = 'inline(K!,w,x,i)';
    my $code = <<EOF;
@!set(K, w[i], x);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_setcoef_ui {
    my $proto = 'inline(K!,w,x,i)';
    my $code = <<EOF;
@!set_ui(K, w[i], x);
EOF
    return [ $proto, $code ];
}


sub code_for_vec_getcoef {
    my $proto = 'inline(K!,x,w,i)';
    my $code = <<EOF;
@!set(K, x, w[i]);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_ur_setcoef {
    my $proto = 'inline(K!,w,x,i)';
    my $code = <<EOF;
@!elt_ur_set(K, w[i], x);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_ur_getcoef {
    my $proto = 'inline(K!,x,w,i)';
    my $code = <<EOF;
@!elt_ur_set(K, x, w[i]);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_set {
    my $proto = 'inline(k!,w,u,n)';
    my $code = <<EOF;
unsigned int i;
for(i = 0; i < n; ++i)
    @!set(k, w[i], u[i]);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_ur_set {
    my $proto = 'inline(k!,w,u,n)';
    my $code = <<EOF;
unsigned int i;
for(i = 0; i < n; ++i)
    @!elt_ur_set(k, w[i], u[i]);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_ur_set_vec {
    my $proto = 'inline(K!,w,u,n)';
    my $code = <<EOF;
unsigned int i;
for(i = 0; i < n; i+=1)
    @!elt_ur_set_elt(K, w[i], u[i]);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_cmp {
    my $proto = 'inline(K!,u,v,n)';
    my $code = <<EOF;
unsigned int i;
for(i = 0; i < n; ++i) {
    int ret = @!cmp(K, u[i], v[i]);
    if (ret != 0)
        return ret;
}
return 0;
EOF
    return [ $proto, $code ];
}

sub code_for_vec_random {
    my $proto = 'inline(K!,w, n, state)';
    my $code = <<EOF;
unsigned int i;
for(i = 0; i < n; ++i)
    @!random(K, w[i], state);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_random2 {
    my $proto = 'inline(K!,w,n, state)';
    my $code = <<EOF;
unsigned int i;
for(i = 0; i < n; ++i)
    @!random2(K, w[i],state);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_is_zero {
    my $code = <<EOF;
unsigned int i;
for(i = 0 ; i < n ; i+=1) {
    if (!@!is_zero(K,r[i])) return 0;
}
return 1;
EOF
    return [ 'inline(K!,r,n)', $code ];
}

1;
