package Mpfq::defaults::vec::addsub;

use strict;
use warnings;

sub code_for_vec_add {
    my $proto = 'inline(K!,w,u,v,n)';
    my $code = <<EOF;
    unsigned int i;
for(i = 0; i < n; i+=1)
    @!add(K, w[i], u[i], v[i]);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_neg {
    my $proto = 'inline(K!,w,u,n)';
    my $code = <<EOF;
    unsigned int i;
for(i = 0; i < n; ++i)
    @!neg(K, w[i], u[i]);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_rev {
    my $proto = 'inline(K!,w,u,n)';
    my $code = <<EOF;
unsigned int nn = n >> 1;
@!elt tmp[1];
@!init(K, tmp);
unsigned int i;
for(i = 0; i < nn; ++i) {
    @!set(K, tmp[0], u[i]);
    @!set(K, w[i], u[n-1-i]);
    @!set(K, w[n-1-i], tmp[0]);
}
if (n & 1)
    @!set(K, w[nn], u[nn]);
@!clear(K, tmp);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_sub {
    my $proto = 'inline(K!,w,u,v,n)';
    my $code = <<EOF;
unsigned int i;
for(i = 0; i < n; ++i)
    @!sub(K, w[i], u[i], v[i]);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_ur_add {
    my $proto = 'inline(K!,w,u,v,n)';
    my $code = <<EOF;
unsigned int i;
for(i = 0; i < n; i+=1)
    @!elt_ur_add(K, w[i], u[i], v[i]);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_ur_sub {
    my $proto = 'inline(K!,w,u,v,n)';
    my $code = <<EOF;
unsigned int i;
for(i = 0; i < n; i+=1)
    @!elt_ur_sub(K, w[i], u[i], v[i]);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_ur_neg {
    my $proto = 'inline(K!,w,u,n)';
    my $code = <<EOF;
unsigned int i;
for(i = 0; i < n; ++i)
    @!elt_ur_neg(K, w[i], u[i]);
EOF
    return [ $proto, $code ];
}


sub code_for_vec_ur_rev {
    my $proto = 'inline(K!,w,u,n)';
    my $code = <<EOF;
unsigned int nn = n >> 1;
@!elt_ur tmp[1];
@!elt_ur_init(K, tmp);
unsigned int i;
for(i = 0; i < nn; ++i) {
    @!elt_ur_set(K, tmp[0], u[i]);
    @!elt_ur_set(K, w[i], u[n-1-i]);
    @!elt_ur_set(K, w[n-1-i], tmp[0]);
}
if (n & 1)
    @!elt_ur_set(K, w[nn], u[nn]);
@!elt_ur_clear(K, tmp);
EOF
    return [ $proto, $code ];
}

1;
