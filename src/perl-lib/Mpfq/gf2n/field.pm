# This is only the initialization and argument checking.
package Mpfq::gf2n::field;

use strict;
use warnings;
use Mpfq::gf2n::utils::poly qw(polyprint);
use Mpfq::engine::utils qw(ceildiv);
use Exporter qw(import);
use Carp;

sub code_for_field_specify { return [ 'macro(k!,dummy!,vp!)' , '' ]; }
sub code_for_field_clear { return [ 'macro(K!)', '' ]; }
sub code_for_field_init {	return [ 'inline(f)', 'f->io_type=16;' ]; }
sub code_for_field_degree {	return [ 'macro(f)', $_[0]->{'n'} ]; }

sub code_for_field_setopt {
    my $code = <<EOF;
assert(x == MPFQ_IO_TYPE);
f->io_type=((unsigned long*)y)[0];
EOF
    return [ 'inline(f,x!,y)', $code ];
}
sub code_for_field_characteristic {
    return [ 'macro(f,x)', "mpz_set_ui(x,2);" ];
}

sub init_handler {
    my ($opt) = @_;

    for my $t (qw/coeffs n w/) {
	croak "missing parameter $t" unless exists $opt->{$t};
    }

    my $n = $opt->{'n'};
    my $w = $opt->{'w'};
    my $banner = "/* Automatically generated code for GF(2^$n) */\n";
    my $poly = polyprint $opt->{'coeffs'};
    $banner .= "/* Definition polynomial P = $poly */\n";

    my $eltwidth = ceildiv $n, $w;
    my $elt_urwidth = ceildiv 2*$n-1, $w;
    my $types = {
	elt =>	"typedef unsigned long @!elt\[$eltwidth\];",
	dst_elt =>	"typedef unsigned long * @!dst_elt;",
	src_elt =>	"typedef const unsigned long * @!src_elt;",

	elt_ur =>	"typedef unsigned long @!elt_ur\[$elt_urwidth\];",
	dst_elt_ur =>	"typedef unsigned long * @!dst_elt_ur;",
	src_elt_ur =>	"typedef const unsigned long * @!src_elt_ur;",

	field	=>	'typedef mpfq_2_field @!field;',
        dst_field	=>	'typedef mpfq_2_dst_field @!dst_field;',

        # We put here the defaults vec types for the moment
        # In the future, binary fields deserve a packed version.
        vec         =>  "typedef @!elt * @!vec;",
        dst_vec     =>  "typedef @!elt * @!dst_vec;",
        src_vec     =>  "typedef @!elt * @!src_vec;",
        vec_ur      =>  "typedef @!elt_ur * @!vec_ur;",
        dst_vec_ur  =>  "typedef @!elt_ur * @!dst_vec_ur;",
        src_vec_ur  =>  "typedef @!elt_ur * @!src_vec_ur;",
        poly        =>  <<EOF,
typedef struct {
  @!vec c;
  unsigned int alloc;
  unsigned int size;
} @!poly_struct;
typedef @!poly_struct @!poly [1];
EOF
        dst_poly => "typedef @!poly_struct * @!dst_poly;",
        src_poly => "typedef @!poly_struct * @!src_poly;",
    };

    return { banner => $banner, types => $types };
}

1;

# vim:set sw=4 sta et:
