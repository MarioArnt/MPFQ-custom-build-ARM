#!/usr/bin/perl

use strict;
use warnings;

my $test_code = <<EOF;
void test_W(mp_limb_t *x, mp_limb_t *y, int N) {
  mp_limb_t z[100];
  mp_limb_t t[100];
  mp_limb_t v[100];
  mp_limb_t c, c1, c2;
#if GMP_LIMB_BITS == 32
  mp_limb_t P[W] = __P32;
#elif GMP_LIMB_BITS == 64
  mp_limb_t P[W] = __P64;
#endif
  int i, j, k;

  memcpy(z, y+17, 10*sizeof(mp_limb_t));
  memcpy(t, z, 10*sizeof(mp_limb_t));

  for(i=0; i < N; ++i) {
    // add
    c1 = mpn_add_n(z, x, y, W);
    c2 = add_W(t, x, y);
    add_nc_W(v, x, y);
    assert (c1 == c2);
    assert (mpn_cmp(z,t,W) == 0);
    assert (mpn_cmp(z,v,W) == 0);
    // sub
    c1 = mpn_sub_n(z, x, y, W);
    c2 = sub_W(t, x, y);
    sub_nc_W(v, x, y);
    assert (c1 == c2);
    assert (mpn_cmp(z,t,W) == 0);
    assert (mpn_cmp(z,v,W) == 0);
    // add_ui
    c1 = mpn_add_1(z, x, W, y[0]);
    c2 = add_ui_W(t, x, y[0]);
    add_ui_nc_W(v, x, y[0]);
    assert (c1 == c2);
    assert (mpn_cmp(z,t,W) == 0);
    assert (mpn_cmp(z,v,W) == 0);
    // sub_ui
    c1 = mpn_sub_1(z, x, W, y[0]);
    c2 = sub_ui_W(t, x, y[0]);
    sub_ui_nc_W(v, x, y[0]);
    assert (c1 == c2);
    assert (mpn_cmp(z,t,W) == 0);
    assert (mpn_cmp(z,v,W) == 0);
    // addmul1
    memcpy(t, z, 10*sizeof(mp_limb_t));
    c = mpn_addmul_1(z, x, W, y[0]);
    z[W] += c;
    addmul1_W(t, x, y[0]);
    assert (mpn_cmp(z,t,W+1) == 0);
    // mul1
    memcpy(t, z, 10*sizeof(mp_limb_t));
    c = mpn_mul_1(z, x, W, y[0]);
    z[W] = c;
    mul1_W(t, x, y[0]);
    assert (mpn_cmp(z,t,W+1) == 0);
    // mul
    mpn_mul_n(z, x, y, W);
    mul_W(t, x, y);
    assert (mpn_cmp(z,t,2*W) == 0);
    // shortmul
    mpn_mul_n(z, x, y, W);
    shortmul_W(t, x, y);
    assert (mpn_cmp(z, t, W) == 0);
    // sqr
    mpn_mul_n(z, x, x, W);
    sqr_W(t, x);
    assert (mpn_cmp(z,t,2*W) == 0);
    // cmp
    j = mpn_cmp(x, y, W);
    k = cmp_W(x, y);
    assert (j==k);
    // mod
    if (y[W-1] == 0)
      y[W-1]++;
    mpn_tdiv_qr(z+W+1, z, 0, x, 2*W, y, W);
    mod_W(t, x, y);
    assert(mpn_cmp(z, t, W) == 0);
    // inv
    mod_W(t, x, P);
    if (t[0] == 0UL)
      t[0] = 1UL;
    invmod_W(z, t, P);
    invmod_W(z, z, P);
    assert(mpn_cmp(z, t, W) == 0);
    //redc
    {
      mp_limb_t p[W], mip[W];
      mp_limb_t xe[W], ye[W], ze[W];
      
      x[W-1] &= 1UL<<(GMP_LIMB_BITS-1) -1;
      y[W-1] &= 1UL<<(GMP_LIMB_BITS-1) -1;
      mpn_random2(p, W);
      p[W-1] &= 1UL<<(GMP_LIMB_BITS-1) -1;
      if (x[W-1] > p[W-1])
        p[W-1] = x[W-1];
      if (y[W-1] > p[W-1])
        p[W-1] = y[W-1];
      p[0] |= 1UL;
      if (p[W-1] == 0)
        p[W-1] = 1;
      // compute inverse of opposite of p mod R, 
      // with iterated  x <- x + x*(p*x+1) mod R
      mip[0] = 1UL;
      for (j = 0; j < 20; ++j) { // 20 is far too much...
        shortmul_W(z, mip, p);
	mpn_add_1(z, z, W, 1);
	shortmul_W(t, z, mip);
	add_W(mip, t, mip);
      }
	
      // encode x
      for(j=0; j<W; j++) {
        z[j] = 0;
	z[j+W] = x[j];
      }
      mod_W(xe, z, p);
      // encode y
      for(j=0; j<W; j++) {
        z[j] = 0;
	z[j+W] = y[j];
      }
      mod_W(ye, z, p);
      // encode x*y mod p
      mul_W(z, x, y);
      mod_W(t, z, p);
      for(j=0; j<W; j++) {
	z[j] = 0;
	z[j+W] = t[j];
      }
      mod_W(ze, z, p);
      // do the product in Mgy form
      mul_W(z, xe, ye);
      redc_W(t, z, mip, p);
      assert(mpn_cmp(ze, t, W) == 0);
    }

    x++; y++;
  }
}
EOF



print <<EOF;
#include <stdio.h>
#include <stdlib.h>
#include <gmp.h>
#include <string.h>
#include <assert.h>
#include "mpfq/fixmp.h"

/* The tests are based on assert() */
#ifdef NDEBUG
#  undef NDEBUG
#endif

EOF

my $i;
my $code_i;
my @primes64 = (
  "{4929763703639915597UL}",
  "{14425133756266440979UL, 7028776506806380750UL}",
  "{9758664018554848775UL, 108797327114284110UL, 3855934483758865187UL}",
"{ 12011675740079661751UL, 3294090837287775300UL, 9673935898323528142UL, 6244774036521541631UL }",
"{ 11766063743839433833UL, 17023338808517031849UL, 6384879829007101141UL, 9814014250957810811UL,5856459693223253397UL }",
"{ 9332489496020345727UL, 13059118375404545793UL, 543826843599586942UL, 568657921352937073UL, 8714542686157595041UL, 8377129812810584371UL }",
"{ 8305431681600953837UL, 8511912794376737076UL, 5827616680491403508UL, 11764963549898802560UL, 9952224619298044241UL, 2593919323804169004UL, 5707166315511930231UL }",
"{ 16672777963903890445UL, 14321543724342516978UL, 5190009058579841038UL, 16894467406687282692UL, 5579682454395466331UL, 3120279582727612446UL, 2933066969036697885UL, 2125779597467003446UL }",
"{ 6272071724723397689UL, 7097496403184731472UL, 6722451164852552420UL, 2557895735561628759UL, 11466998160538807963UL, 18232042263112599551UL, 4641538801156436724UL, 16426483130014462608UL, 7262099965674661736UL }",
);

my @primes32 = (
"{ 2041087589UL, }",
"{ 1737731653UL, 3654705850UL, }",
"{ 3826833745UL, 2279976717UL, 3984871455UL, }",
"{ 3662469475UL, 2096692762UL, 4151755841UL, 4009865730UL, }",
"{ 4034459419UL, 3797792253UL, 1419478273UL, 2675749510UL, 3664727098UL, }",
"{ 2813719779UL, 3907769622UL, 704006380UL, 1485932037UL, 661860009UL, 2968664580UL, }",
"{ 3784709369UL, 269443326UL, 4028649229UL, 2906318846UL, 1307656400UL, 167308958UL, 3095675918UL, }",
"{ 4093166397UL, 205402748UL, 1827875733UL, 2591432089UL, 498572719UL, 2575114975UL, 3040974997UL, 3977792999UL, }",
"{ 3897809411UL, 1993283498UL, 867915630UL, 886471665UL, 3987868346UL, 2967702854UL, 1194285669UL, 1588068146UL, 928806807UL, }",
);

for ($i=1; $i<10; $i++) {
  $code_i = $test_code;
  $code_i =~ s/W/$i/g;
  $code_i =~ s/__P32/$primes32[$i-1]/g;
  $code_i =~ s/__P64/$primes64[$i-1]/g;
  print $code_i, "\n";
}


print <<EOF;
int main(int argc, char **argv) {
  mp_limb_t *x, *y;
  int N=1000;
  int k=100;

  if (argc==2)
    k = atoi(argv[1]);

  x = (mp_limb_t *)malloc((N+100)*sizeof(mp_limb_t));
  y = (mp_limb_t *)malloc((N+100)*sizeof(mp_limb_t));

  for (;k>=0;--k) {
    mpn_random2(x, N+100);
    mpn_random2(y, N+100);

    test_1(x,y,N);
    test_2(x,y,N);
    test_3(x,y,N);
    test_4(x,y,N);
    test_5(x,y,N);
    test_6(x,y,N);
    test_7(x,y,N);
    test_8(x,y,N);
    test_9(x,y,N);
    printf("."); fflush(stdout);
  }
  printf("\\n");
  return 0;
}
EOF
