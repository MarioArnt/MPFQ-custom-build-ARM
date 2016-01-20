package Mpfq::defaults::vec::mul;

use strict;
use warnings;

# These are separated from the rest because the relevance of having these
# functions is essentially dependent on the availability of a mul()
# operation, and the companions mul_ur() and reduce()

sub code_for_vec_scal_mul_ur {
    my $proto = 'inline(K!,w,u,x,n)';
    my $code = <<EOF;
unsigned int i;
for(i = 0; i < n; i+=1)
    @!mul_ur(K, w[i], u[i], x);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_reduce {
    my $proto = 'inline(K!,w,u,n)';
    my $code = <<EOF;
unsigned int i;
for(i = 0; i < n; i+=1)
    @!reduce(K, w[i], u[i]);
EOF
    return [ $proto, $code ];
}

sub code_for_vec_scal_mul {
    my $proto = 'inline(K!,w,u,x,n)';
    my $code = <<EOF;
    unsigned int i;
for(i = 0; i < n; i+=1)
    @!mul(K, w[i], u[i], x);
EOF
    return [ $proto, $code ];
}

1;
