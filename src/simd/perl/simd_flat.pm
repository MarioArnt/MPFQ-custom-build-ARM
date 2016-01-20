package simd_flat;

use strict;
use warnings;
use Mpfq::defaults::flatdata;

our @parents = qw/Mpfq::defaults::flatdata/;

########################################################################
# Not that stuff here is also almost valid for non-flat data. Only the
# calculation of storage differs.

sub code_for_random {
    # FIXME. This looks fairly stupid.
    my $code = <<EOC;
    for(unsigned int i = 0 ; i < sizeof(@!elt) ; i++) {
        ((unsigned char*)r)[i] = gmp_urandomb_ui(state, 8);
    }
EOC
    return [ 'inline(K!,r,state)', $code ];
}

sub code_for_set_zero {
    return [ 'inline(K!,r)', "memset(r, 0, sizeof(@!elt));" ];
}

sub code_for_set_ui_at {
    my $code=<<EOF;
    assert(k < @!groupsize(K));
    uint64_t * xp = (uint64_t *) p;
    uint64_t mask = ((uint64_t)1) << (k%64);
    xp[k/64] = (xp[k/64] & ~mask) | ((((uint64_t)v) << (k%64))&mask);
EOF
    return [ 'inline(K!,p,k,v)', $code ];
}

sub code_for_set_ui_all {
    my $code=<<EOF;
    for(unsigned int i = 0 ; i < sizeof(@!elt)/sizeof(*r) ; i++) {
        r[i] = ~v;
    }
EOF
    return [ 'inline(K!,r,v)', $code ];
}

sub code_for_elt_ur_set_ui_at { return code_for_set_ui_at(@_); }
sub code_for_elt_ur_set_ui_all { return code_for_set_ui_all(@_); }


########################################################################

# the vec_add from Mpfq::defaults::vec::addsub is fine. Normally the
# compiler understands that this all folds down to simple arithmetic.

1;
