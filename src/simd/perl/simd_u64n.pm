package simd_u64n;

# This version imposes an extra indirection.
#
use strict;
use warnings;

use simd_noflat;

our @parents = qw/simd_noflat/;

sub code_for_groupsize { return [ 'macro(K)', "64 * *K" ]; }
sub code_for_field_specify {
    my ($opt) = @_;
    my $kind = 'function(K!,tag,x)';
    my $groupsize = $opt->{'k'} * 64;
    my $code = <<EOF;
    if (tag == MPFQ_GROUPSIZE) {
        assert(*(int*)x % 64 == 0);
        *K = *(int*)x / 64;
    } else if (tag == MPFQ_PRIME_MPZ) {
        assert(mpz_cmp_ui((mpz_srcptr)x, 2) == 0);
    } else {
        fprintf(stderr, "Unsupported field_specify tag %ld\\n", tag);
    }
EOF
    return [ $kind, $code ];
}


sub init_handler {
    my ($opt) = @_;

    my $banner = "/* Automatically generated code  */\n";

    my $vtag = $opt->{'tag'};

    my $types = {
	elt =>	"typedef uint64_t * @!elt;",
	dst_elt =>	"typedef uint64_t * @!dst_elt;",
	src_elt =>	"typedef uint64_t const * @!src_elt;",

	elt_ur =>	"typedef uint64_t * @!elt_ur;",
	dst_elt_ur =>	"typedef uint64_t * @!dst_elt_ur;",
	src_elt_ur =>	"typedef uint64_t const * @!src_elt_ur;",

	field	=>	'typedef unsigned int @!field[1];',
        dst_field	=>	'typedef unsigned int * @!dst_field;',

        variable_field => "typedef abase_${vtag}_field @!variable_field;",
        variable_dst_field => "typedef abase_${vtag}_dst_field @!variable_dst_field;",
        variable_dst_elt => "typedef abase_${vtag}_dst_elt @!variable_dst_elt;",
        variable_dst_vec => "typedef abase_${vtag}_dst_vec @!variable_dst_vec;",
        variable_src_elt => "typedef abase_${vtag}_src_elt @!variable_src_elt;",
        variable_src_vec => "typedef abase_${vtag}_src_vec @!variable_src_vec;",
    };

    return { banner => $banner, types => $types };
}

1;

