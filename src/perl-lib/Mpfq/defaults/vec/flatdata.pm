package Mpfq::defaults::vec::flatdata;

use strict;
use warnings;

sub code_for_vec_set {
    return [ 'inline(K!,r,s,n)', "if (r != s) memmove(r, s, n*sizeof(@!elt));" ];
}

sub code_for_vec_ur_set {
    return [ 'inline(K!,r,s,n)', "if (r != s) memmove(r, s, n*sizeof(@!elt_ur));" ];
}

sub code_for_vec_set_zero {
    return [ 'inline(K!,r,n)', "memset(r, 0, n*sizeof(@!elt));" ];
}

sub code_for_vec_ur_set_zero {
    return [ 'inline(K!,r,n)', "memset(r, 0, n*sizeof(@!elt_ur));" ];
}

1;
