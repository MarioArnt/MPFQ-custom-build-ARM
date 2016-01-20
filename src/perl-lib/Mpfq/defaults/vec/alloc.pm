package Mpfq::defaults::vec::alloc;

use strict;
use warnings;

sub code_for_vec_init {
    my $proto = 'function(K!,v,n)';
    my $code = <<EOF;
unsigned int i;
*v = (@!vec) malloc (n*sizeof(@!elt));
for(i = 0; i < n; i+=1)
    @!init(K, (*v) + i);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_reinit {
    my $proto = 'function(K!,v,n,m)';
    my $code = <<EOF;
if (n < m) { // increase size
    unsigned int i;
    *v = (@!vec) realloc (*v, m * sizeof(@!elt));
    for(i = n; i < m; i+=1)
        @!init(K, (*v) + i);
} else if (m < n) { // decrease size
    unsigned int i;
    for(i = m; i < n; i+=1)
        @!clear(K, (*v) + i);
    *v = (@!vec) realloc (*v, m * sizeof(@!elt));
}
EOF
    return [ $proto, $code ];
}

sub code_for_vec_clear {
    my $proto = 'function(K!,v,n)';
    my $code = <<EOF;
    unsigned int i;
for(i = 0; i < n; i+=1)
    @!clear(K, (*v) + i);
free(*v);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_ur_init {
    my $proto = 'function(K!,v,n)';
    my $code = <<EOF;
unsigned int i;
*v = (@!vec_ur) malloc (n*sizeof(@!elt_ur));
for(i = 0; i < n; i+=1)
    @!elt_ur_init(K, &( (*v)[i]));
EOF
    return [ $proto, $code ];
}

sub code_for_vec_ur_reinit {
    my $proto = 'function(K!,v,n,m)';
    my $code = <<EOF;
if (n < m) { // increase size
    *v = (@!vec_ur) realloc (*v, m * sizeof(@!elt_ur));
    unsigned int i;
    for(i = n; i < m; i+=1)
        @!elt_ur_init(K, (*v) + i);
} else if (m < n) { // decrease size
    unsigned int i;
    for(i = m; i < n; i+=1)
        @!elt_ur_clear(K, (*v) + i);
    *v = (@!vec_ur) realloc (*v, m * sizeof(@!elt_ur));
}
EOF
    return [ $proto, $code ];
}

sub code_for_vec_ur_clear {
    my $proto = 'function(K!,v,n)';
    my $code = <<EOF;
unsigned int i;
for(i = 0; i < n; i+=1)
    @!elt_ur_clear(K, &( (*v)[i]));
free(*v);
EOF
    return [ $proto, $code ];
}

1;
