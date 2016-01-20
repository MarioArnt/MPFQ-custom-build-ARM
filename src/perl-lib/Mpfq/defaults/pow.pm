package Mpfq::defaults::pow;

use strict;
use warnings;

sub code_for_pow {
    my $opt = shift @_;
    my $w = $opt->{'w'};
    my $proto = 'inline(k,res,r,x,n)';
    my $code = <<EOF;
@!elt u, a;
long i, j, lead;     /* it is a signed type */
unsigned long mask;

assert (n>0);

/* get the correct (i,j) position of the most significant bit in x */
for(i = n-1; i>=0 && x[i]==0; i--)
    ;
if (i < 0) {
    @!set_ui(k, res, 0);
    return;
}
j = $w - 1;
mask = (1UL<<j);
for( ; (x[i]&mask)==0 ;j--, mask>>=1)
    ;
lead = i*$w+j;      /* Ensured. */

@!init(k, &u);
@!init(k, &a);
@!set(k, a, r);
for( ; lead > 0; lead--) {
    if (j-- == 0) {
        i--;
        j = $w-1;
        mask = (1UL<<j);
    } else {
        mask >>= 1;
    }
    if (x[i]&mask) {
        @!sqr(k, u, a);
        @!mul(k, a, u, r);
    } else {
        @!sqr(k, a,a);
    }
}
@!set(k, res, a);
@!clear(k, &u);
@!clear(k, &a);
EOF
    return [ $proto, $code ];
}

1;
