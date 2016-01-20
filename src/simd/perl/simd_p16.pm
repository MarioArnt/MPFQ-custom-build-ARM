package simd_p16;

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


use p16;
our @parents = qw/p16/;

my $groupsize = 1;      # This layer does not allow modification f the
                        # group size.

# set_zero: keep
sub code_for_set_ui_at {
    die unless $groupsize == 1;
    my $code=<<EOF;
    assert(k < @!groupsize(K));
    *p = v;
EOF
    return [ 'inline(K!,p,k!,v)', $code ];
}

sub code_for_set_ui_all {
    die unless $groupsize == 1;
    return [ 'inline(K!,p,v)', "*p=v;" ];
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
    int64_t s = 0;
    for(unsigned int i = 0 ; i < n ; i++) {
        s+=((int64_t) xu0[i][0]) * ((int64_t) xu1[i][0]);
    }
    xw[0][0] = s % (int64_t) *K;
EOF
    return [ $kind, $code ];
}

# As above, we do not support for the moment anything different from simd
# group size being one. So easy again.
sub code_for_member_template_dotprod {
    die unless $groupsize == 1;
    my $kind = "function(K0!,K1!,xw,xu1,xu0,n)";
    my $code = <<EOF;
    int64_t s = 0;
    for(unsigned int i = 0 ; i < n ; i++) {
        s+=((int64_t) xu0[i][0]) * ((int64_t) xu1[i][0]);
    }
    xw[0][0] =s % (int64_t) *K0;
EOF
    return [ $kind, $code ];
}

# Once again...
sub code_for_member_template_addmul_tiny {
    die unless $groupsize == 1;
    my $kind = "function(K!,L!,w,u,v,n)";
    my $code = <<EOF;
    for(unsigned int i = 0 ; i < n ; i++) {
        w[i][0] += u[i][0] * v[0][0];
    }
EOF
    return [ $kind, $code ];
}

sub code_for_member_template_transpose {
    # Note that member templates don't like macros !
    die unless $groupsize == 1;
    return [ "function(K!,L!,w,u)", "w[0][0]=u[0][0];" ];
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

sub code_for_addmul_si_ur { return [ 'macro(K!,r,s1,v)', "*r += *s1 * v" ]; }


sub init_handler {
    my ($opt) = @_;

    my $banner = "/* Automatically generated code  */\n";

    die unless $opt->{'tag'} eq 'p16';
    $opt->{'vtag'} = $opt->{'tag'};

    return {
        banner => $banner,
        'th:includes' => [ qw/"abase_p16.h"/ ],
        'c:includes' => [qw/<inttypes.h>/]};
}

1;
