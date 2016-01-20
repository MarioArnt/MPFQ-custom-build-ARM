package Mpfq::gfp::field;

use strict;
use warnings;

sub code_for_field_degree { return [ 'macro(K!)', '1' ]; }

sub code_for_field_characteristic {
    my $proto = 'function(k,z)';
    my $opt = shift @_;
    my $w = $opt->{'w'};
    my $code = <<EOF;
int i;
int n = k->kl;
mpz_set_ui(z, k->p[n-1]);
for (i = n-2; i >= 0; --i) {
    mpz_mul_2exp(z, z, $w);
    mpz_add_ui(z, z, k->p[i]);
}
EOF
    return [ $proto, $code ];
}

sub code_for_field_specify {
    my $opt = shift @_;
    my $w = $opt->{'w'};
    my $n = $opt->{'n'};
    my $nn = $opt->{'nn'};
    my $code = '';
    $code .= <<EOF;
    if (k->p == NULL) k->p = (mp_limb_t *)malloc($n*sizeof(mp_limb_t));
    if (k->bigmul_p == NULL) k->bigmul_p = (mp_limb_t *)malloc($nn*sizeof(mp_limb_t));
    if ((!k->p) || (!k->bigmul_p))
        MALLOC_FAILED();
    k->kl = $n;
    k->url = $nn;
    k->url_margin = LONG_MAX;
    int i;
    if (dummy == MPFQ_PRIME_MPN) {
        mp_limb_t *p = (mp_limb_t*) vp;
        memcpy(k->p, p, $n*sizeof(mp_limb_t));
    } else if (dummy == MPFQ_PRIME_MPZ) {
        mpz_srcptr p = (mpz_srcptr) vp;
        assert(mpz_size(p) == $n);
        for(i = 0 ; i < $n ; i++) {
            k->p[i] = mpz_getlimbn(p, i);
        }
    } else if (dummy == MPFQ_GROUPSIZE && *(int*)vp == 1) {
        /* Do nothing, this is an admitted condition */
    } else {
        abort();
    }
EOF
    $code .= <<EOF;
// precompute bigmul_p = largest multiple of p that fits in an elt_ur,
//   p*Floor( (2^($nn*$w)-1)/p )
{
    @!elt_ur big;
    mp_limb_t q[$nn-$n+1], r[$n], tmp[$nn+1];
    
    for (i = 0; i < $nn; ++i)
        big[i] = ~0UL;
    mpn_tdiv_qr(q, r, 0, big, $nn, k->p, $n);
    mpn_mul(tmp, q, $nn-$n+1, k->p, $n);
    for (i = 0; i < $nn; ++i)
        (k->bigmul_p)[i] = tmp[i];
    assert (tmp[$nn] == 0UL);
}
EOF
    return [ 'function(k,dummy!,vp)' , $code ]; 
}

sub code_for_field_init { 
    my $opt = shift @_;
    my $type = $opt->{'type'};
    my $code = <<EOF;
k->p = NULL;
k->bigmul_p = NULL;
k->io_base = 10;
mpz_init(k->factor);
k->ts_info.e=0;
EOF
    return [ 'inline(k)', $code ];
}

sub code_for_field_clear {
    my $opt = shift @_;
    my $type = $opt->{'type'};
    my $code = '';
    $code .= <<EOF;
if (k->p != NULL) {
    free(k->p);
    k->p = NULL;
}
EOF
    $code .= <<EOF;
if (k->bigmul_p != NULL) {
    free(k->bigmul_p);
    k->bigmul_p = NULL;
}
if (k->ts_info.e > 0) {
    free(k->ts_info.hh);
    free(k->ts_info.z);
}
mpz_clear(k->factor);
EOF
    return [ 'function(k)', $code ];
}

sub code_for_field_setopt { return [ 'macro(f,x,y)' , '' ]; }

sub init_handler {
    return { includes=>[ qw{
              <limits.h>
              "mpfq/fixmp.h"
              "mpfq/mpfq_gfp_common.h"
              }],
      };
}


1;
