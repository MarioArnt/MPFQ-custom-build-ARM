package Mpfq::gfp::mgy::field;

use strict;
use warnings;

use Mpfq::gfp::field;

our @parents = qw/Mpfq::gfp::field/;

# piggy-back on default code.
sub code_for_field_clear {
    my $normal = Mpfq::gfp::field::code_for_field_clear(@_);
    my ($kind,$code,@gens) = @$normal;
    my $pre = <<EOF;
if (k->mgy_info.invR != NULL) {
    free(k->mgy_info.invR);
    k->mgy_info.invR = NULL;
}
if (k->mgy_info.invP != NULL) {
    free(k->mgy_info.invP);
    k->mgy_info.invP = NULL;
}
EOF
    return [$kind, $pre . $code, @gens];
}

sub code_for_redc_init {
  my $tmpl = 'dst_field';
  my $kind = 'function(k)';

  my $code = <<EOF;
mp_limb_t *tmp, *tmp2, *tmp3;
int i, logsize;
mp_limb_t *p = k->p;
int n = k->kl;

tmp = (mp_limb_t *) malloc(2*n*sizeof(mp_limb_t));
tmp2 = (mp_limb_t *) malloc(2*n*sizeof(mp_limb_t));
tmp3 = (mp_limb_t *) malloc(2*n*sizeof(mp_limb_t));
if ( (!tmp) || (!tmp2) || (!tmp3) )
  MALLOC_FAILED();

tmp[0] = 1UL;
for (i = 1; i < 2*n; ++i)
  tmp[i] = 0UL;

logsize = 1;
for (i = 1; i < n*GMP_LIMB_BITS; i<<=1)
  logsize++;

for (i = 0; i < logsize+1; ++i) {  // do one more loop, to be one the safe side
  mpn_mul_n(tmp2, tmp, tmp, n);    //  x*x
  mpn_mul_n(tmp3, tmp2, p, n);     //  p*x*x
  mpn_lshift(tmp, tmp, n, 1);      //  2*x
  mpn_sub_n(tmp, tmp, tmp3, n);       //  2x - p*x*x
}

for (i = 0; i < n; ++i)
  tmp2[i] = 0UL;

mpn_sub_n(k->mgy_info.invP, tmp2, tmp, n);

tmp2[0] = 1UL;
for (i = 1; i < 2*n; ++i)
  tmp2[i] = 0UL;
mpn_mul_n(tmp3, tmp, p, n);
mpn_sub_n(tmp, tmp3, tmp2, 2*n);
mpn_tdiv_qr(tmp2, k->mgy_info.invR, 0, tmp+n, n, p, n);

mpn_sub_n(k->mgy_info.invR, p, k->mgy_info.invR, n);
free(tmp);
free(tmp2);
free(tmp3);
EOF

  return { kind => $kind,
    name => "redc_init",
    requirements => $tmpl,
    code => $code};
}

# piggy-back on default code.
sub code_for_field_specify {
    my $opt = $_[0];
    my $normal = Mpfq::gfp::field::code_for_field_specify(@_);
    my $n = $opt->{'n'};
    my ($kind,$code,@gens) = @$normal;
    my $post = <<EOF;
if (k->mgy_info.invR == NULL) 
    k->mgy_info.invR = (mp_limb_t *)malloc($n*sizeof(mp_limb_t));
if (k->mgy_info.invP == NULL) 
    k->mgy_info.invP = (mp_limb_t *)malloc($n*sizeof(mp_limb_t));
if ((!k->mgy_info.invR) || (!k->mgy_info.invP))
    MALLOC_FAILED();
@!redc_init(k);
EOF
    return [ $kind , $code . $post, @gens, code_for_redc_init() ];
}

# piggy-back on default code.
sub code_for_field_init {
    my $normal = Mpfq::gfp::field::code_for_field_init(@_);
    my ($kind,$code,@gens) = @$normal;
    my $post = <<EOF;
k->mgy_info.invR = NULL;
k->mgy_info.invP = NULL;
EOF
    return [ $kind , $code . $post, @gens ];
}

sub init_handler {
    return { includes=>[ qw{
              <limits.h>
              "mpfq/fixmp.h"
              "mpfq/mpfq_gfp_common.h"
              }],
      };
}


1;
