package gf7;

use strict;
use warnings;

use Mpfq::engine::handler;
our @ISA = qw/Mpfq::engine::handler/;
sub new { return bless({},shift); }

use Mpfq::defaults;
use Mpfq::defaults::flatdata;
use Mpfq::defaults::poly;

# List of packages from which we inherit. These must also be listed with
# the ``use'' statements above. The @parents array is examined for
# finding the code generation methods eventually.
our @parents = qw/
    Mpfq::defaults
    Mpfq::defaults::flatdata
    Mpfq::defaults::poly
/;


# The packages from which we inherit provide ambiguous resolutions for
# some methods. It is possible to fix this by making the inheritance
# diagram unambigous (a class' implementations always wins over its
# parents. Beyond that, no two parents of a class should provide distinct
# implementations of a given function).
# The other way to fix it is explicitly, as we do here.
our $resolve_conflicts = {
    vec_set => 'Mpfq::defaults::flatdata',
    vec_ur_set => 'Mpfq::defaults::flatdata',
};


sub code_for_field_specify { return [ 'macro(k!,dummy!,vp!)' , '' ]; }
sub code_for_field_init { return [ 'macro(K!)', '' ]; }
sub code_for_field_clear { return [ 'macro(K!)', '' ]; }
sub code_for_field_setopt { return [ 'macro(f,x,y)' , '' ]; }
sub code_for_field_degree { return [ 'macro(K!)', '1' ]; }
sub code_for_field_characteristic { return [ 'macro(K!,z)', 'mpz_set_ui(z,7)' ]; }


# A very basic example of implementation of the 'add' function of the
# api.
sub code_for_add {
    return [ 'inline(K!, z, x, y)', "z = (x+y)%7;" ];
}

# Some more complicated example, with a helper function.
# We want to implement 'sub' by calling a helper function that does an
# unreduced subtract, and then reduce mod 7.
sub code_for_sub_helper {
    return {
        kind=>'inline(z, x, y)',
        name=>'sub_helper',
        requirements=>'dst_elt src_elt src_elt',
        code=>'z = x-y;',
    };
}
# The function called by the automatic generator should return as usual
# its proto and its code, but additionnally a hash describing the helper
# function (there might be several of them).
sub code_for_sub {
    my $proto = 'inline(k, z, x, y)';
    my $code = '';
    $code .= "@!sub_helper(z, x, y);\n";
    $code .= "if ((long)z < 0)\n";
    $code .= "      z += 7;\n";
    return [ $proto, $code, code_for_sub_helper() ];
}

# A trivial routine for mul.
sub code_for_mul {
    my $code = 'z = (x * y) % 7;';
    return [ 'inline(k, z, x, y)', $code ];
}    

sub init_handler {
  #Initialize typedef:
  my $types = {
    elt =>	"typedef unsigned long @!elt\[1\];",
    dst_elt =>	"typedef unsigned long * @!dst_elt;",
    src_elt =>	"typedef const unsigned long * @!src_elt;",

    elt_ur =>	"typedef unsigned long @!elt_ur\[1\];",
    dst_elt_ur =>	"typedef unsigned long * @!dst_elt_ur;",
    src_elt_ur =>	"typedef const unsigned long * @!src_elt_ur;",

    field	=>	'typedef void * @!field;',
    dst_field	=>	'typedef void * @!dst_field;',
  };
  return { types => $types };
}


1;

