package simd_gfp;

# This gives a shot to GF(p) arithmetic only based on short 32-bit
# multiplication, signed. So adapted to 16-bit p at most.
#
# We're being slightly gross in the constraints at the moment, in that we
# require that products computed can be accumulated and never exceed 2^32
# until they're reduced. Of course this must be changed.


use strict;
use warnings;

use Mpfq::engine::handler;
use Mpfq::engine::oo;
our @ISA = qw/
    Mpfq::engine::handler
    Mpfq::engine::oo
/;
sub new { return bless({},shift); }


use Mpfq::gfp;
use Mpfq::defaults::mpi_flat;
our @parents = qw/
    Mpfq::gfp
    Mpfq::defaults::mpi_flat
/;

my $groupsize = 1;      # This layer does not allow modification of the
                        # group size.

# set_zero: keep
sub code_for_set_ui_at {
    die unless $groupsize == 1;
    return [ 'inline(K!,p,k!,v)', "@!set_ui(K,p,v);" ];
}

sub code_for_set_ui_all {
    die unless $groupsize == 1;
    return [ 'inline(K!,p,v)', "@!set_ui(K,p,v);" ];
}

sub code_for_elt_ur_set_ui_at { return code_for_set_ui_at(@_); }
sub code_for_elt_ur_set_ui_all { return code_for_set_ui_all(@_); }

############################################################
# --- dot products now.
#

# Here we are in a context where the SIMD group size is 1, for the
# moment. So the output of dotprod is simply a scalar. Easy.
sub code_for_dotprod {
    die unless $groupsize == 1;
    my $kind = "function(K!,xw,xu1,xu0,n)";
    my $code = <<EOF;
    @!elt_ur s,t;
    @!elt_ur_init(K, &s);
    @!elt_ur_init(K, &t);
    @!elt_ur_set_zero(K, s);
    for(unsigned int i = 0 ; i < n ; i++) {
        @!mul_ur(K, t, xu0[i], xu1[i]);
        @!elt_ur_add(K, s, s, t);
    }
    @!reduce(K, xw[0], s);
    @!elt_ur_clear(K, &s);
    @!elt_ur_clear(K, &t);
EOF
    return [ $kind, $code ];
}

# As above, we do not support for the moment anything different from simd
# group size being one. So easy again.
sub code_for_member_template_dotprod {
    die unless $groupsize == 1;
    my $kind = "function(K0!,K1!,xw,xu1,xu0,n)";
    my $code = <<EOF;
    @!elt_ur s,t;
    @!elt_ur_init(K0, &s);
    @!elt_ur_init(K0, &t);
    @!elt_ur_set_zero(K0, s);
    for(unsigned int i = 0 ; i < n ; i++) {
        @!mul_ur(K0, t, xu0[i], xu1[i]);
        @!elt_ur_add(K0, s, s, t);
    }
    @!reduce(K0, xw[0], s);
    @!elt_ur_clear(K0, &s);
    @!elt_ur_clear(K0, &t);
EOF
    return [ $kind, $code ];
}

# Once again...
sub code_for_member_template_addmul_tiny {
    die unless $groupsize == 1;
    my $kind = "function(K!,L!,w,u,v,n)";
    my $code = <<EOF;
    @!elt s;
    @!init(K, &s);
    for(unsigned int i = 0 ; i < n ; i++) {
        @!mul(K, s, u[i], v[0]);
        @!add(K, w[i], w[i], s);
    }
    @!clear(K, &s);
EOF
    return [ $kind, $code ];
}

sub code_for_member_template_transpose {
    # Note that member templates don't like macros !
    die unless $groupsize == 1;
    return [ "function(K!,L!,w,u)", "@!set(K, w[0], u[0]);" ];
}

########################################################################
# --- This is part of the syntactic sugar around the whole thing.

# Here we're not requesting compatibility with other implementations.
# sub code_for_field_init_oo_change_groupsize {
#     my $kind = "function(K!,f,v)";
#     my $code = <<EOF;
# assert(v == $groupsize); */
# abase_p16_field_init_oo(NULL, f);
# (f->set_groupsize)(f, v);
# EOF
#     return [ $kind, $code ];
# }


sub code_for_groupsize { return [ 'macro(K!)', $groupsize ]; }
sub code_for_set_groupsize { return [ 'macro(K!,n)', "assert(n==$groupsize)" ]; } 
sub code_for_offset { return [ 'macro(K!,n)', 'n /* TO BE DEPRECATED */' ]; }
sub code_for_stride { return [ 'macro(K!)', '1 /* TO BE DEPRECATED */' ]; }

sub code_for_addmul_si_ur {
    # This would be a feature request. For the moment the code we give
    # here sucks.
    my $kind = 'inline(K!, w, u, v)';
    my $code = <<EOF;
    @!elt_ur s;
    @!elt vx;
    @!elt_ur_init(K, &s);
    @!init(K, &vx);
    if (v>0) {
        @!set_ui(K, vx, v);
        @!mul_ur(K, s, u, vx);
        @!elt_ur_add(K, w, w, s);
    } else {
        @!set_ui(K, vx, -v);
        @!mul_ur(K, s, u, vx);
        @!elt_ur_sub(K, w, w, s);
    }
    @!clear(K, &vx);
    @!elt_ur_clear(K, &s);
EOF
    return [ $kind, $code ];
}

sub init_handler {
    my ($opt) = @_;

    my $banner = "/* Automatically generated code  */\n";

    die unless $opt->{'tag'} =~ /^p_\d+$/;
    $opt->{'vtag'} = $opt->{'tag'};

    my $tag = $opt->{'tag'};

    return {
        banner => $banner,
        'th:includes' => [ qq{"abase_$tag.h"} ],
        'c:includes' => [qw/<inttypes.h>/]};
}

1;
