package Mpfq::gfpmgy;

use strict;
use warnings;

use Mpfq::engine::handler;

use Mpfq::defaults;
use Mpfq::defaults::vec::conv;
use Mpfq::defaults::poly;

use Mpfq::gfp::mgy::codec;
use Mpfq::gfp::mgy::field;
use Mpfq::gfp::mgy::elt;
use Mpfq::gfp::mgy::io;

our @parents = qw/
    Mpfq::defaults
    Mpfq::defaults::vec::conv
    Mpfq::defaults::poly

    Mpfq::gfp::mgy::codec
    Mpfq::gfp::mgy::field
    Mpfq::gfp::mgy::elt
    Mpfq::gfp::mgy::io
/;

our $resolve_conflicts = {
    vec_set => 'Mpfq::gfp::mgy::elt',
    vec_ur_set => 'Mpfq::gfp::mgy::elt',
};

our @ISA = qw/Mpfq::engine::handler/;

# This one is really a hack. Why on earth does this code insist on not
# using @!cmp_ui ?? XXX

#Why using mgy_dec?
#sub code_for_is_sqr {
#    my $proto = 'inline(k,x)';
#    my $opt = shift @_;
#    my $n = $opt->{'n'};
#    my $code = <<EOF;
#mp_limb_t pp[$n];
#@!elt y;
#sub_ui_nc_$n(pp, k->p, 1);
#rshift_$n(pp, 1);
#@!init(k, &y);
#@!pow(k, y, x, pp, $n);
#EOF
#        $code = $code . <<EOF;
#@!mgy_dec(k, y, y);
#EOF
#    $code = $code . <<EOF;
#int res = cmp_ui_$n(y, 1);
#@!clear(k, &y);
#if (res == 0)
#    return 1;
#else 
#    return 0;
#EOF
#    return [ $proto, $code ];
#}

#Why decoding at the end of reduce?
#sub code_for_reduce {
#  my $opt = $_[0];
#  my $n = $opt->{'n'};
#  my $w = $opt->{'w'};
#  my $nn = $opt->{'nn'};
#  my $proto = 'inline(k, z, x)';
#  my $code = <<EOF;
#mp_limb_t q[$nn+1];
#if (x[$nn-1]>>($w-1)) {
#    // negative number, add bigmul_p to make it positive before reduction
#    mpn_add_n(x, x, k->bigmul_p, $nn);
#}
#mpn_tdiv_qr(q, z, 0, x, $nn, k->p, $n);
#@!mgy_dec(k, z, z);
#EOF
#  return  [ $proto, $code ];
#}

#sub code_for_reduce_2n {
#  my $opt = $_[0];
#  my $n = $opt->{'n'};
#  my $widen = 2*$n;
#  my $proto = 'inline(k, r, s)';
#  my $code = <<EOF;
#redc_$n(r, s, k->mgy_info.invP, k->p);
#EOF
#  return  {
#      kind=>$proto,
#      code=>$code,
#      requirements=>'dst_field dst_elt dst_elt_ur',
#      name=>'reduce_2n' };
#}


#sub code_for_mul {
#  my $opt = $_[0];
#  my $n = $opt->{'n'};
#  my $code;
#  if ($n == 1) {
#      $code = <<EOF;
##ifdef HAVE_NATIVE_MULREDC_1
#mulredc_1(r, s1, s2, k->p, k->mgy_info.invP);
##else
#@!elt_ur z;
#@!elt_ur_init(k, &z);
#@!mul_ur(k, z, s1, s2);
#@!reduce_2n(k, r, z);
#@!elt_ur_clear(k, &z);
##endif
#EOF
#
#  } else {
#  $code = <<EOF;
#@!elt_ur z;
#@!elt_ur_init(k, &z);
#@!mul_ur(k, z, s1, s2);
#@!reduce_2n(k, r, z);
#@!elt_ur_clear(k, &z);
#EOF
#  }
#  return [ 'inline(k, r, s1, s2)', $code, code_for_reduce_2n($opt) ];
#}

#sub code_for_sqr {
#  my $opt = $_[0];
#  my $n = $opt->{'n'};
#  my $code;
#  if ($n == 1) {
#      $code = <<EOF;
##ifdef HAVE_NATIVE_SQRREDC_1
#sqrredc_1(r, s1, k->p, k->mgy_info.invP);
##elif defined(HAVE_NATIVE_MULREDC_1)
#mulredc_1(r, s1, s1, k->p, k->mgy_info.invP);
##else
#@!elt_ur z;
#@!elt_ur_init(k, &z);
#@!sqr_ur(k, z, s1);
#@!reduce_2n(k, r, z);
#@!elt_ur_clear(k, &z);
##endif
#EOF
#  } else {
#  $code = <<EOF;
#@!elt_ur z;
#@!elt_ur_init(k, &z);
#@!sqr_ur(k, z, s1);
#@!reduce_2n(k, r, z);
#@!elt_ur_clear(k, &z);
#EOF
#  }
#  return [ 'inline(k, r, s1)', $code ];
#}

#sub code_for_inv {
#  my $opt = $_[0];
#  my $n = $opt->{'n'};
#  my $code = <<EOF;
#int ret;
#mgy_decode_$n(z, x, k->mgy_info.invR, k->p);
#ret = invmod_$n(z, z, k->p);
#if (ret) {
#  mgy_encode_$n(z, z, k->p);
#  return 1;
#} else {
#  mgy_encode_$n(z, z, k->p);
#  @!get_mpz(k, k->factor, z);
#  return 0;
#}
#EOF
#  return [ 'inline(k, z, x)', $code ];
#}

sub new { return bless({},shift); }

1;
