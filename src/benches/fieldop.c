#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <gmp.h>

#include "timing.h"

#include "mpfq/mpfq_TAG.h"


int main(int argc, char** argv) {
  mpfq_TAG_field k;
  mp_limb_t p[TAG_SIZE_P] = TAGP;
  mpfq_TAG_elt x,y,z,t;
  mpfq_TAG_elt_ur z_ur;
  long i, j=2;
  const long N = 1000000;
  uint64_t t_start, t_end, t_cal;
  double tps;
  uint64_t ticks[100];

  if (argc == 2) {
    j = atol(argv[1]);
  }

  mpfq_TAG_field_init(k); 
  mpfq_TAG_field_specify(k, MPFQ_PRIME_MPN, p); 
  mpfq_TAG_init(k, &x);
  mpfq_TAG_init(k, &y);
  mpfq_TAG_init(k, &z);
  mpfq_TAG_init(k, &t);
  
  mpfq_TAG_init(k, &t);

#define BENCHITX(__X__,__N__,__CMD__,__NAME__) \
  t_start = microseconds(); \
  for (i = 0; i < __N__/__X__; ++i) { \
	  asm volatile ("#begin ");	\
    __CMD__ \
	  asm volatile ("#end ");	\
  } \
  t_end = microseconds(); \
  tps = (double)(t_end - t_start); \
  tps /= (double)(__N__/__X__); \
  tps /= (double)__X__; \
  printf(__NAME__  " %f\n", tps); 
#define BENCHIT(__N__,__CMD__,__NAME__) BENCHITX(1,__N__,__CMD__,__NAME__)


  for(; j>0; --j) {
    mpfq_TAG_random(k, x);
    mpfq_TAG_random(k, y);
    mpfq_TAG_random(k, z);
    do { mpfq_TAG_random(k, t); } while (mpfq_TAG_cmp_ui(k, t, 0) == 0);

    BENCHIT(N,mpfq_TAG_add(k, z, x, y);,"add")
    BENCHIT(N,mpfq_TAG_sub(k, z, x, y);,"sub")
//    BENCHIT(N,mpfq_TAG_mul_ui(k, z, x, 6333521614034024423UL);,"mul_ui")
    BENCHIT(N,mpfq_TAG_mul_ur(k, z_ur, x, y);,"mul_ur")
    BENCHIT(N,mpfq_TAG_sqr_ur(k, z_ur, x);,"sqr_ur")
    BENCHIT(N,mpfq_TAG_reduce(k, z, z_ur);,"reduce")
    BENCHITX(3,N,
		    mpfq_TAG_mul(k, z, x, y);
		    mpfq_TAG_mul(k, x, y, z);
		    mpfq_TAG_mul(k, y, z, x);
		    ,"mul")
    // BENCHIT(N,mpfq_TAG_sqr(k, z, x);,"sqr")
    BENCHITX(3, N,
            mpfq_TAG_sqr(k, z, x);
            mpfq_TAG_sqr(k, y, z);
            mpfq_TAG_sqr(k, x, y);
            ,"sqr")
    BENCHIT((N/100),mpfq_TAG_inv(k, z, t);,"inv")
  }

  return 0;
}

