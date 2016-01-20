package Mpfq::defaults::flatdata;

use strict;
use warnings;

use Mpfq::defaults::vec::flatdata;

our @parents = qw/
    Mpfq::defaults::vec::flatdata
/;

# The functions provided here are simple proxies, usually macros or
# inlines, which are appropriate for the situation where the elements and
# vectors to be considered hold no indirect storage. Currently, this
# applies in fact to all of mpfq !

sub code_for_init {     	return [ 'macro(f,px)', '']; }
sub code_for_clear {    	return [ 'macro(f,px)', '']; }
sub code_for_elt_ur_init {     	return [ 'macro(f,px)', '']; }
sub code_for_elt_ur_clear {    	return [ 'macro(f,px)', '']; }

sub code_for_vec_elt_stride { return [ 'macro(K!,n)', "((n)*sizeof(@!elt))" ]; } 


# Here we have default wrappers for most basic operations. These comply
# with the api, although it would be possible to implement them in a
# shorter way. Code-wise, it is expected that in the trivial case, all
# loops in the generated code fold down to nothing when nothing has to be
# done.
sub code_for_set {
    return [ 'inline(K!,r,s)', "if (r != s) memcpy(r,s,sizeof(@!elt));" ];
}

sub code_for_elt_ur_set {
    return [ 'inline(K!,r,s)', "if (r != s) memcpy(r,s,sizeof(@!elt_ur));" ];
}

sub code_for_set_zero {
    return [ 'inline(K!,r)', "@!vec_set_zero(K,(@!dst_vec)r,1);" ];
}

sub code_for_elt_ur_set_zero {
    return [ 'inline(K!,r)', "memset(r, 0, sizeof(@!elt_ur));" ];
}

sub code_for_elt_ur_set_elt {
    return [ 'inline(K!,r,s)', "memset(r, 0, sizeof(@!elt_ur)); memcpy(r,s,sizeof(@!elt));" ];
}

sub code_for_is_zero {
    my $code = <<EOF;
    unsigned int i;
    for(i = 0 ; i < sizeof(@!elt)/sizeof(r[0]) ; i++) {
        if (r[i]) return 0;
    }
    return 1;
EOF
    return [ 'inline(K!,r)', $code ];
}

# note that memcmp makes little sense for the simd interface, as we
# rather case about the per-member comparison and not about the whole
# thing.
sub code_for_cmp {
    return [ 'inline(K!,r,s)', "return memcmp(r,s,sizeof(@!elt));" ];
}

1;
