/*
 * Author: Pierrick Gaudry
 *
 * Purpose: implement the Curve25519 cryptosystem of D. Bernstein
 *   see http://cr.yp.to/ecdh.html 
 *
 * Modulus is p=2^255-19  
 *
 * About 7500 scalar mul per sec on an Opteron 250 at 2.4 GHz.
 * About 6500 scalar mul per sec on a Core2 6700 at 2.66 GHz.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <gmp.h>

#include "mpfq/mpfq_p_25519.h"

// EC arithmetic.

typedef struct {
  mpfq_p_25519_elt x;
  mpfq_p_25519_elt z;
} ECpoint_struct;

typedef ECpoint_struct ECpoint[1];
typedef ECpoint_struct * dst_ECpoint;
typedef const ECpoint_struct * src_ECpoint;

static void ECinit(mpfq_p_25519_dst_field k, dst_ECpoint P) {
  mpfq_p_25519_init(k, &(P->x));
  mpfq_p_25519_init(k, &(P->z));
}

static void ECclear(mpfq_p_25519_dst_field k, dst_ECpoint P) {
  mpfq_p_25519_clear(k, &(P->x));
  mpfq_p_25519_clear(k, &(P->z));
}

static void ECcopy(mpfq_p_25519_dst_field k, dst_ECpoint Q, src_ECpoint P) {
  mpfq_p_25519_set(k, Q->x, P->x);
  mpfq_p_25519_set(k, Q->z, P->z);
}

// NB: 121666 is (A+2)/4 mod p, where A = 486662
static void ECdouble(mpfq_p_25519_dst_field k, dst_ECpoint Q, src_ECpoint P) {
  mpfq_p_25519_elt tmp1, tmp2, tmp3, tmp4;

  mpfq_p_25519_init(k, &tmp1); mpfq_p_25519_init(k, &tmp2);
  mpfq_p_25519_init(k, &tmp3); mpfq_p_25519_init(k, &tmp4);

  mpfq_p_25519_sub(k, tmp1, P->x, P->z);
  mpfq_p_25519_add(k, tmp2, P->x, P->z);
  mpfq_p_25519_sqr(k, tmp1, tmp1);
  mpfq_p_25519_sqr(k, tmp2, tmp2);
  mpfq_p_25519_sub(k, tmp3, tmp2, tmp1);

  mpfq_p_25519_mul(k, Q->x, tmp1, tmp2);
  mpfq_p_25519_mul_ui(k, tmp4, tmp3, 121666UL);
  mpfq_p_25519_add(k, Q->z, tmp4, tmp1);
  mpfq_p_25519_mul(k, Q->z, Q->z, tmp3);
  
  mpfq_p_25519_clear(k, &tmp1); mpfq_p_25519_clear(k, &tmp2);
  mpfq_p_25519_clear(k, &tmp3); mpfq_p_25519_clear(k, &tmp4);
}

void ECprint(mpfq_p_25519_field k, src_ECpoint P) {
  mpfq_p_25519_print(k, P->x); printf("\n");
  mpfq_p_25519_print(k, P->z); printf("\n");
}

// scalar multiplication on Curve25519.
// key is 4 limb long.
void ECmul(mpfq_p_25519_dst_field k, mpfq_p_25519_dst_elt res, mpfq_p_25519_src_elt x, mpz_t key) {
  ECpoint Pm, Pp;
  ECpoint_struct *pm, *pp, *tmp;
  mpfq_p_25519_elt tmp1, tmp2, tmp3, tmp4;
  int i, l;

  if (mpz_cmp_ui(key, 0)==0) {
    // implement me!
    assert (0);
  }

  if (mpz_cmp_ui(key, 1)==0) {
    mpfq_p_25519_set(k, res, x);
    return;
  }

  ECinit(k, Pm); ECinit(k, Pp);
  mpfq_p_25519_set(k, Pm->x, x);
  mpfq_p_25519_set_ui(k, Pm->z, 1);
  ECdouble(k, Pp, Pm);

  if (mpz_cmp_ui(key, 2)==0) {
    mpfq_p_25519_inv(k, Pp->z, Pp->z);
    mpfq_p_25519_mul(k, res, Pp->x, Pp->z);
    ECclear(k, Pm); ECclear(k, Pp);
    return;
  }

  // allocate memory (should be NOP in practice, since this is on the
  // stack).
  mpfq_p_25519_init(k, &tmp1); mpfq_p_25519_init(k, &tmp2);
  mpfq_p_25519_init(k, &tmp3); mpfq_p_25519_init(k, &tmp4);
  
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
    mpfq_p_25519_sub(k, tmp1, pm->x, pm->z);
    mpfq_p_25519_add(k, tmp2, pm->x, pm->z);

    mpfq_p_25519_sub(k, tmp3, pp->x, pp->z);
    mpfq_p_25519_add(k, tmp4, pp->x, pp->z);

    mpfq_p_25519_mul(k, tmp4, tmp1, tmp4);
    mpfq_p_25519_mul(k, tmp3, tmp2, tmp3);

    mpfq_p_25519_add(k, pp->x, tmp3, tmp4);
    mpfq_p_25519_sub(k, pp->z, tmp3, tmp4);
    mpfq_p_25519_sqr(k, pp->x, pp->x);
    mpfq_p_25519_sqr(k, pp->z, pp->z);
    mpfq_p_25519_mul(k, pp->z, pp->z, x);

    // double pm  -> pm
    mpfq_p_25519_sqr(k, tmp1, tmp1);
    mpfq_p_25519_sqr(k, tmp2, tmp2);
    mpfq_p_25519_sub(k, tmp3, tmp2, tmp1);

    mpfq_p_25519_mul(k, pm->x, tmp1, tmp2);
    mpfq_p_25519_mul_ui(k, tmp4, tmp3, 121666UL);
    mpfq_p_25519_add(k, pm->z, tmp4, tmp1);
    mpfq_p_25519_mul(k, pm->z, pm->z, tmp3);

    if (swap) {
      tmp = pp; pp = pm; pm = tmp;
    }
  }
  mpfq_p_25519_inv(k, pm->z, pm->z);
  mpfq_p_25519_mul(k, res, pm->x, pm->z);
  
  ECclear(k, Pm); ECclear(k, Pp);
  mpfq_p_25519_clear(k, &tmp1); mpfq_p_25519_clear(k, &tmp2);
  mpfq_p_25519_clear(k, &tmp3); mpfq_p_25519_clear(k, &tmp4);
}

int main(int argc, char** argv) {
  mpz_t key;
  // dst_field and field are the same type for this field.
  mpfq_p_25519_field k;
  mpfq_p_25519_elt res, base_point;
  int i;

  mpfq_p_25519_field_init(k);

  if (argc != 3) {
    fprintf(stderr, "usage: %s key base_point\n", argv[0]);
    fprintf(stderr, "    key        is the secret key (an integer < 2^256)\n");
    fprintf(stderr, "    base_point is the abscissa of the point to multiply (an integer < 2^256)\n");
    return 1;
  }
  mpz_init_set_str(key, argv[1], 10);
  mpfq_p_25519_init(k, &base_point);
  mpfq_p_25519_sscan(k, base_point, argv[2]);
  
  mpfq_p_25519_init(k, &res);
  for (i = 0; i < 1000; ++i) {
    ECmul(k, res, base_point, key);
  }
  mpfq_p_25519_print(k, res); printf("\n");

  mpfq_p_25519_clear(k, &base_point);
  mpfq_p_25519_clear(k, &res);
  mpfq_p_25519_field_clear(k);
  mpz_clear(key);
  return 0; 
}

#if 0

----------------------------------------------------------------------
Some Magma code for testing.
----------------------------------------------------------------------
p := 2^255-19;
Fp := GF(p);
A := Fp!486662;
E := EllipticCurve([0,A,0,1,0]);

Abs := Fp!9;
key := 21348576;
PP := Points(E, Abs);
assert #PP eq 2;
P := PP[1];
Q := key*P;
Q[1];

#endif
