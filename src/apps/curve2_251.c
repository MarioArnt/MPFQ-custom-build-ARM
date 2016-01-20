#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <gmp.h>
#include <assert.h>

#include "mpfq/mpfq_2_251.h"

// EC arithmetic.


typedef struct {
  mpfq_2_251_elt x;
  mpfq_2_251_elt z;
} ECpoint_struct;

typedef ECpoint_struct ECpoint[1];
typedef ECpoint_struct * dst_ECpoint;
typedef const ECpoint_struct * src_ECpoint;

static void ECinit(mpfq_2_251_field k, dst_ECpoint P) {
  mpfq_2_251_init(k, &(P->x));
  mpfq_2_251_init(k, &(P->z));
}

static void ECclear(mpfq_2_251_field k, dst_ECpoint P) {
  mpfq_2_251_clear(k, &(P->x));
  mpfq_2_251_clear(k, &(P->z));
}

static void ECcopy(mpfq_2_251_field k, dst_ECpoint Q, src_ECpoint P) {
  mpfq_2_251_set(k, Q->x, P->x);
  mpfq_2_251_set(k, Q->z, P->z);
}

static void ECdouble(mpfq_2_251_field k, dst_ECpoint Q, src_ECpoint P, mpfq_2_251_src_elt A6) {
  mpfq_2_251_elt tmp1;

  mpfq_2_251_init(k, &tmp1); 
  
  mpfq_2_251_sqr(k, Q->x, P->x);
  mpfq_2_251_sqr(k, tmp1, P->z);
  mpfq_2_251_mul(k, Q->z, tmp1, Q->x);
  mpfq_2_251_add(k, Q->x, Q->x, tmp1);
  mpfq_2_251_sqr(k, Q->x, Q->x);
  mpfq_2_251_mul(k, Q->x, A6, Q->x);  // TODO: mul_uipoly, here.
  
  mpfq_2_251_clear(k, &tmp1);
}

void ECprint(mpfq_2_251_field k, src_ECpoint P) {
  mpfq_2_251_print(k, P->x); printf(" ");
  mpfq_2_251_print(k, P->z);
}

// scalar multiplication on Curve2_251.
void ECmul(mpfq_2_251_field k, mpfq_2_251_dst_elt res, mpfq_2_251_src_elt x, mpz_t key) {
  ECpoint Pm, Pp;
  ECpoint_struct *pm, *pp, *tmp;
  mpfq_2_251_elt tmp1, tmp2;
  mpfq_2_251_elt A6;
  int i, l;

  mpfq_2_251_init(k, &A6);
  mpfq_2_251_set_uipoly(k, A6, 9095);

  if (mpz_cmp_ui(key, 0)==0) {
    // implement me!
    assert (0);
  }

  if (mpz_cmp_ui(key, 1)==0) {
    mpfq_2_251_set(k, res, x);
    mpfq_2_251_clear(k, &A6);
    return;
  }

  ECinit(k, Pm); ECinit(k, Pp);
  mpfq_2_251_set(k, Pm->x, x);
  mpfq_2_251_set_ui(k, Pm->z, 1);
  ECdouble(k, Pp, Pm, A6);

  if (mpz_cmp_ui(key, 2)==0) {
    mpfq_2_251_inv(k, Pp->z, Pp->z);
    mpfq_2_251_mul(k, res, Pp->x, Pp->z);
    mpfq_2_251_clear(k, &A6);
    ECclear(k, Pm); ECclear(k, Pp);
    return;
  }

  // allocate memory (should be NOP in practice, since this is on the
  // stack).
  mpfq_2_251_init(k, &tmp1); mpfq_2_251_init(k, &tmp2);
  
  // initialize loop
  pm = Pm;
  pp = Pp;

  // loop
  l = mpz_sizeinbase(key, 2);
  assert (mpz_tstbit(key, l-1) == 1);
  for (i = l-2; i >= 0; --i) {
    int swap;
    swap = (mpz_tstbit(key, i) == 1);
    if (swap) {
      tmp = pp; pp = pm; pm = tmp;
    }

    // pseudo add -> pp
    mpfq_2_251_add(k, tmp1, pm->x, pm->z);
    mpfq_2_251_add(k, tmp2, pp->x, pp->z);
    mpfq_2_251_mul(k, tmp1, tmp1, tmp2);

    mpfq_2_251_mul(k, pp->x, pm->x, pp->x);
    mpfq_2_251_mul(k, pp->z, pm->z, pp->z);
    mpfq_2_251_add(k, pp->x, pp->x, pp->z);
    mpfq_2_251_add(k, pp->z, pp->x, tmp1);

    mpfq_2_251_sqr(k, pp->x, pp->x);
    mpfq_2_251_sqr(k, pp->z, pp->z);
    mpfq_2_251_mul(k, pp->z, pp->z, x);

    // double pm  -> pm
    mpfq_2_251_sqr(k, pm->x, pm->x);
    mpfq_2_251_sqr(k, tmp1, pm->z);
    mpfq_2_251_mul(k, pm->z, tmp1, pm->x);
    mpfq_2_251_add(k, pm->x, pm->x, tmp1);
    mpfq_2_251_sqr(k, pm->x, pm->x);
    // mpfq_2_251_mul(k, pm->x, pm->x, A6);
    mpfq_2_251_mul_uipoly(k, pm->x, pm->x, 9095);


      if (swap) {
      tmp = pp; pp = pm; pm = tmp;
    }
  }
#if 0
  { unsigned long bb = 'T'; mpfq_2_251_field_setopt(k, MPFQ_IO_TYPE, &bb); }
  ECprint(k,pm);printf("\n");
  { unsigned long bb = 10; mpfq_2_251_field_setopt(k, MPFQ_IO_TYPE, &bb); }
#endif
  mpfq_2_251_inv(k, pm->z, pm->z);
  mpfq_2_251_mul(k, res, pm->x, pm->z);
  
  ECclear(k, Pm); ECclear(k, Pp);
  mpfq_2_251_clear(k, &tmp1); mpfq_2_251_clear(k, &tmp2);
}



int main(int argc, char** argv) {
  mpz_t key;
  mpfq_2_251_field k;
  mpfq_2_251_elt res, base_point;
  int i;

  mpfq_2_251_field_init(k); 
  {
      mp_limb_t base = 10;
      mpfq_2_251_field_setopt(k, MPFQ_IO_TYPE, &base);
  }

  if (argc != 3) {
    fprintf(stderr, "usage: %s key base_point\n", argv[0]);
    fprintf(stderr, "    key        is the secret key (an integer < 2^256)\n");
    fprintf(stderr, "    base_point is the abscissa of the point to multiply (an integer < 2^256)\n");
    return 1;
  }
  mpz_init_set_str(key, argv[1], 10);
  mpfq_2_251_init(k, &base_point);
  mpfq_2_251_sscan(k, base_point, argv[2]);
  
  mpfq_2_251_init(k, &res);
  for (i = 0; i < 1000; ++i) {
    ECmul(k, res, base_point, key);
  }
  mpfq_2_251_print(k, res); printf("\n");

  mpfq_2_251_clear(k, &base_point);
  mpfq_2_251_clear(k, &res);
  mpz_clear(key);
  return 0; 
}

#if 0

Some Magma code for testing.

PP<t> := PolynomialRing(GF(2));
Fq<T> := ext<GF(2) | t^251 + t^7 + t^4 + t^2 + 1>;
A6 := T^13 + T^9 + T^8 + T^7 + T^2 + T + 1;
E := EllipticCurve([1,0,0,0,A6]);

N := 3618502788666131106986593281521497120350295568660281842639600273604847968132;
Nt := 3618502788666131106986593281521497120479078472942253409826498726889722634366;



#endif
