package p16;

use strict;
use warnings;

use Mpfq::engine::handler;
our @ISA = qw/Mpfq::engine::handler/;
sub new { return bless({},shift); }

use Mpfq::defaults;
use Mpfq::defaults::mpi_flat;
use io;
use trivialities;
use simd_flat;

our @parents=qw/
    Mpfq::defaults
    Mpfq::defaults::mpi_flat
    io
    trivialities
    simd_flat
/;

our $resolve_conflicts = {
    vec_ur_set => 'simd_flat',
    vec_set => 'simd_flat',
    print => 'io',
    fprint => 'io',
};

my $eltwidth = 1;       # and our base type is int32
my $elt_urwidth = 1;    # and our base type is int32


############################################################
# --- quick review through the I/O part of the api.

# I/O conventions differ from binary, of course.
sub code_for_asprint {
    my $code = <<EOF;
    *ps = malloc(13);
    if (!*ps) MALLOC_FAILED();
    snprintf(*ps, 13, "%" PRId32, *x);
EOF
    return [ 'function(K!, ps, x)', $code ];
}

# fprint uses asprint, so keep it
# print: ditto

sub code_for_sscan {
    my $opt = shift @_;
    my $proto = 'function(k!,z,str)';
    my $code = 'return sscanf(str, "%" SCNd32, z) == 1;';
    return [ $proto, $code ];
}

# fscan: Ok, the default is an horror, but we'll keep it as well.

sub code_for_scan {
    return [ 'macro(k,x)', '@!fscan(k,stdin,x)' ];
}

############################################################
# --- this would probably be a simd_charp interface.

sub code_for_field_degree { return [ 'macro(K)', '1' ]; }
sub code_for_field_init { return [ 'macro(f)', '' ]; }
sub code_for_field_clear { return [ 'macro(f)', '' ]; }
sub code_for_field_characteristic { return [ 'inline(K,z)', 'mpz_set_si(z,*K);' ]; }
sub code_for_field_setopt { return [ 'macro(f,x,y)' , '' ]; }
sub code_for_field_specify {
    my ($opt) = @_;
    my $kind = 'function(K!,tag,x!)';
    my $code = <<EOF;
    if (tag == MPFQ_GROUPSIZE) {
        assert(*(int*)x == 1);
    } else if (tag == MPFQ_PRIME_MPZ) {
        assert(mpz_cmp_ui((mpz_srcptr)x, 1 << 16) < 0);
        assert(mpz_cmp_ui((mpz_srcptr)x, 0) > 0);
        *K = mpz_get_ui((mpz_srcptr)x);
    } else {
        fprintf(stderr, "Unsupported field_specify tag %ld\\n", tag);
    }
EOF
    return [ $kind, $code ];
}



########################################################################
# --- some changes on top of simd_flat
# --- this part would have to go alongside with element types.

sub code_for_reduce {
    # Cannot be a macro !
    return [ "inline(K,x,y)", "*x = *y % *K; *x += *K & -(*x < 0);"];
}

sub code_for_add { return [ 'inline(K!,r,s1,s2)', "*r = *s1 + *s2; @!reduce(K, r, r);" ]; }
sub code_for_sub { return [ "inline(K!,r,s1,s2)", "*r = *s1 - *s2; @!reduce(K, r, r);" ]; }
sub code_for_neg { return [ 'inline(K!,r,s)',     "*r =  *r - *s;  @!reduce(K, r, r);" ]; }

sub code_for_random {
    # FIXME -- it's dumb !
    # die unless $groupsize == 1;
    # Note that because we're dereferencing K, we can't have a macro.
    return [ 'inline(K,r,state)', "*r = gmp_urandomm_ui(state, *K);" ];
}

# elt_ur_set_zero: keep

sub code_for_elt_ur_add { return [ 'macro(K!,r,s1,s2)', "*r = *s1 + *s2" ]; }
sub code_for_elt_ur_sub { return [ "macro(K!,r,s1,s2)", "*r = *s1 - *s2" ]; }
sub code_for_elt_ur_neg { return [ 'macro(K!,r,s)', "*r=-*s" ]; }



sub init_handler {
  #Initialize typedef:
  my $types = {
    elt =>	"typedef int32_t @!elt\[1\];",
    dst_elt =>	"typedef int32_t * @!dst_elt;",
    src_elt =>	"typedef const int32_t * @!src_elt;",

    elt_ur =>	"typedef int32_t @!elt_ur\[1\];",
    dst_elt_ur =>	"typedef int32_t * @!dst_elt_ur;",
    src_elt_ur =>	"typedef const int32_t * @!src_elt_ur;",

    field	=>	'typedef int32_t @!field[1];',
    dst_field	=>	'typedef int32_t * @!dst_field;',
  };
  return { types => $types };
}


1;

