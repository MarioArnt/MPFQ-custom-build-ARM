package simd_u64k;

use strict;
use warnings;

use Mpfq::engine::handler;
use Mpfq::engine::oo;

use Mpfq::defaults;
use Mpfq::defaults::mpi_flat;
use simd_dotprod;
use io;
use trivialities;
use simd_char2;
use simd_flat;

our @parents = qw/
    Mpfq::defaults
    Mpfq::defaults::mpi_flat
    simd_dotprod
    io
    trivialities
    simd_char2
    simd_flat/;

our $resolve_conflicts = {
    vec_set => 'simd_flat',
    vec_ur_set => 'simd_flat',
    print => 'io',
    fprint => 'io',
};

our @ISA = qw/
    Mpfq::engine::handler
    Mpfq::engine::oo
/;

my $eltwidth;
my $groupsize;

sub new { my $class = shift; return bless({}, $class); }

sub code_for_field_clear { return [ 'macro(K!)', '' ]; }
sub code_for_field_init {       return [ 'inline(f!)', '' ]; }
sub code_for_field_degree {     return [ 'macro(f)', '1' ]; }
sub code_for_field_setopt { return [ 'macro(f,x!,y)', '' ]; }

sub code_for_groupsize { return [ 'macro(K!)', $groupsize ]; }
sub code_for_field_specify {
    my ($opt) = @_;
    my $kind = 'function(K!,tag,x!)';
    my $groupsize = $opt->{'k'} * 64;
    my $code = <<EOF;
    if (tag == MPFQ_GROUPSIZE) {
        assert(*(int*)x == $groupsize);
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

    my $vtag = $opt->{'vtag'};
    if (!defined($vtag)) {
        $vtag = $opt->{'tag'};
        if (!($vtag =~ s/u64(?:k\d+|n|)$/u64n/)) {
            die "Cannot lexically derive vtag name." .
                " Please supply on command line."
        }
    }

    $eltwidth = $opt->{'k'};
    my $elt_urwidth = $eltwidth;
    $groupsize = 64*$eltwidth;
    my $types = {
	elt =>	"typedef uint64_t @!elt\[$eltwidth\];",
	dst_elt =>	"typedef uint64_t * @!dst_elt;",
	src_elt =>	"typedef const uint64_t * @!src_elt;",

	elt_ur =>	"typedef uint64_t @!elt_ur\[$elt_urwidth\];",
	dst_elt_ur =>	"typedef uint64_t * @!dst_elt_ur;",
	src_elt_ur =>	"typedef const uint64_t * @!src_elt_ur;",

	field	=>	'typedef void * @!field[1];',
        dst_field	=>	'typedef void * @!dst_field;',

#         variable_field => "typedef abase_${vtag}_field @!variable_field;",
#         variable_dst_field => "typedef abase_${vtag}_dst_field @!variable_dst_field;",
#         variable_dst_elt => "typedef abase_${vtag}_dst_elt @!variable_dst_elt;",
#         variable_dst_vec => "typedef abase_${vtag}_dst_vec @!variable_dst_vec;",
#         variable_src_elt => "typedef abase_${vtag}_src_elt @!variable_src_elt;",
#         variable_src_vec => "typedef abase_${vtag}_src_vec @!variable_src_vec;",
};

# return { includes=> [qw/"abase_u64n.h"/], banner => $banner, types => $types };
    return {
            banner => $banner,
            types => $types,
        };
}

1;

