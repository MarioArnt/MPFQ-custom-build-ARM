package simd_char2;

use strict;
use warnings;

# This gather everything which follows completely trivially from the fact
# that we are essentially a replica of GF(2)

sub code_for_add {
    my $code = <<EOF;
    for(unsigned int i = 0 ; i < sizeof(@!elt)/sizeof(*r) ; i++) {
        r[i] = s1[i] ^ s2[i];
    }
EOF
    return [ 'inline(K!,r,s1,s2)', $code ];
}

sub code_for_elt_ur_add { return code_for_add(@_); }
sub code_for_field_degree { return [ 'macro(K!)', '1' ]; }
sub code_for_field_characteristic { return [ 'macro(K!,z)', 'mpz_set_ui(z,2)' ]; }
sub code_for_neg { return [ 'macro(K!,r,s)', "@!set(K,r,s)" ]; }
sub code_for_elt_ur_neg { return [ 'macro(K!,r,s)', "@!elt_ur_set(K,r,s)" ]; }
sub code_for_elt_ur_sub {
    return [ "macro(K!,r,s1,s2)", "@!elt_ur_add(K,r,s1,s2)" ];
}
sub code_for_sub { return [ "macro(K!,r,s1,s2)", "@!add(K,r,s1,s2)" ]; }

# We are missing them in the automatically generated code. Let's just put
# placeholders, as no real code is programmed to use them yet.
sub init_handler {
    my $opt = shift;
    my $elt_types = {};
    $elt_types->{"poly"} = <<EOF;
typedef struct {
  @!vec c;
  unsigned int alloc;
  unsigned int size;
} @!poly_struct;
typedef @!poly_struct @!poly [1];
EOF
    $elt_types->{"dst_poly"} = "typedef @!poly_struct * @!dst_poly;";
    $elt_types->{"src_poly"} = "typedef @!poly_struct * @!src_poly;";
    return { types => $elt_types };
}

1;

