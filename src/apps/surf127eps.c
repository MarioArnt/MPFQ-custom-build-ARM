/*
 * Author: Pierrick Gaudry
 *
 * Purpose: implement a Kummer cryptosystem on GF(2^127-eps)
 *   see  "Fast genus 2 arithmetic based on Theta functions" by P. Gaudry.
 *
 * The curve is a CM one, computed using Thomas Houtmann's tools.
 *
 * Modulus is p=2^127-735
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <gmp.h>

#include "mpfq/mpfq_p_127_735.h"

// Kummer arithmetic.

typedef struct {
  mpfq_p_127_735_elt x;
  mpfq_p_127_735_elt y;
  mpfq_p_127_735_elt z;
  mpfq_p_127_735_elt t;
} KSpoint_struct;

typedef KSpoint_struct KSpoint[1];
typedef KSpoint_struct * dst_KSpoint;
typedef const KSpoint_struct * src_KSpoint;

typedef struct {
  mpfq_p_127_735_elt y0;
  mpfq_p_127_735_elt z0;
  mpfq_p_127_735_elt t0;
  mpfq_p_127_735_elt y0p;
  mpfq_p_127_735_elt z0p;
  mpfq_p_127_735_elt t0p;
} KSparam_struct;

typedef KSparam_struct KSparam[1];
typedef const KSparam_struct * src_KSparam;

//--------------------

static void KSinit(mpfq_p_127_735_field k, dst_KSpoint P) {
  mpfq_p_127_735_init(k, &(P->x));
  mpfq_p_127_735_init(k, &(P->y));
  mpfq_p_127_735_init(k, &(P->z));
  mpfq_p_127_735_init(k, &(P->t));
}

static void KSclear(mpfq_p_127_735_field k, dst_KSpoint P) {
  mpfq_p_127_735_clear(k, &(P->x));
  mpfq_p_127_735_clear(k, &(P->y));
  mpfq_p_127_735_clear(k, &(P->z));
  mpfq_p_127_735_clear(k, &(P->t));
}

static void KScopy(mpfq_p_127_735_field k, dst_KSpoint Q, src_KSpoint P) {
  mpfq_p_127_735_set(k, Q->x, P->x);
  mpfq_p_127_735_set(k, Q->y, P->y);
  mpfq_p_127_735_set(k, Q->z, P->z);
  mpfq_p_127_735_set(k, Q->t, P->t);
}

// do Hadamard-like transform in place: 8 Adds.
static void KShadamard(mpfq_p_127_735_field k, dst_KSpoint P) {
#if 0
  mpfq_p_127_735_elt tmp;
  mpfq_p_127_735_init(k, &tmp);

  mpfq_p_127_735_add(k, tmp, P->x, P->y);
  mpfq_p_127_735_sub(k, P->y, P->x, P->y);
  mpfq_p_127_735_set(k, P->x, tmp);

  mpfq_p_127_735_add(k, tmp, P->z, P->t);
  mpfq_p_127_735_sub(k, P->t, P->z, P->t);
  mpfq_p_127_735_set(k, P->z, tmp);

  mpfq_p_127_735_sub(k, tmp, P->x, P->z);
  mpfq_p_127_735_add(k, P->x, P->x, P->z);
  mpfq_p_127_735_add(k, P->z, P->y, P->t);
  mpfq_p_127_735_sub(k, P->t, P->y, P->t);
  mpfq_p_127_735_set(k, P->y, tmp);
  mpfq_p_127_735_clear(k, &tmp); 
#else
  mpfq_p_127_735_hadamard(k, P->x, P->y, P->z, P->t);
#endif
}


static void KSdouble(mpfq_p_127_735_field k, dst_KSpoint Q, src_KSpoint P, 
    src_KSparam KS) {
  KScopy(k, Q, P);
  KShadamard(k, Q);
  mpfq_p_127_735_sqr(k, Q->x, Q->x);
  mpfq_p_127_735_sqr(k, Q->y, Q->y);
  mpfq_p_127_735_mul(k, Q->y, Q->y, KS->y0p);
  mpfq_p_127_735_sqr(k, Q->z, Q->z);
  mpfq_p_127_735_mul(k, Q->z, Q->z, KS->z0p);
  mpfq_p_127_735_sqr(k, Q->t, Q->t);
  mpfq_p_127_735_mul(k, Q->t, Q->t, KS->t0p);
  KShadamard(k, Q);
  mpfq_p_127_735_sqr(k, Q->x, Q->x);
  mpfq_p_127_735_sqr(k, Q->y, Q->y);
  mpfq_p_127_735_mul(k, Q->y, Q->y, KS->y0);
  mpfq_p_127_735_sqr(k, Q->z, Q->z);
  mpfq_p_127_735_mul(k, Q->z, Q->z, KS->z0);
  mpfq_p_127_735_sqr(k, Q->t, Q->t);
  mpfq_p_127_735_mul(k, Q->t, Q->t, KS->t0);
}

void KSprint(mpfq_p_127_735_field k, src_KSpoint P) {
  mpfq_p_127_735_print(k, P->x); printf(" ");
  mpfq_p_127_735_print(k, P->y); printf(" ");
  mpfq_p_127_735_print(k, P->z); printf(" ");
  mpfq_p_127_735_print(k, P->t);
}

// scalar multiplication on Surf127_735.
// key is 4 limb long.
void KSmul(mpfq_p_127_735_field k, dst_KSpoint res, src_KSpoint P, mpz_t key,
    src_KSparam KS) {
  KSpoint Pm, Pp;
  mpfq_p_127_735_elt tmpy, tmpz, tmpt;
  mpfq_p_127_735_elt YY, ZZ, TT;
  KSpoint_struct *pm, *pp, *tmp;
  int i, l;

  if (mpz_cmp_ui(key, 0)==0) {
    // implement me!
    assert (0);
  }

  if (mpz_cmp_ui(key, 1)==0) {
    KScopy(k, res, P);
    return;
  }

  KSinit(k, Pm); KSinit(k, Pp);
  KScopy(k, Pm, P);
  KSdouble(k, Pp, Pm, KS);

  if (mpz_cmp_ui(key, 2)==0) {
    KScopy(k, res, Pp);
    KSclear(k, Pm);
    KSclear(k, Pp);
    return;
  }

  mpfq_p_127_735_init(k, &tmpy);
  mpfq_p_127_735_init(k, &tmpz);
  mpfq_p_127_735_init(k, &tmpt);

  mpfq_p_127_735_init(k, &YY);
  mpfq_p_127_735_init(k, &ZZ);
  mpfq_p_127_735_init(k, &TT);

  mpfq_p_127_735_mul(k, tmpy, P->y, P->z);
  mpfq_p_127_735_mul(k, tmpz, tmpy, P->t);
  mpfq_p_127_735_inv(k, tmpz, tmpz);
  mpfq_p_127_735_mul(k, tmpz, tmpz, P->x);
  mpfq_p_127_735_mul(k, TT, tmpz, tmpy); // x/t
  mpfq_p_127_735_mul(k, tmpy, P->z, P->t);
  mpfq_p_127_735_mul(k, YY, tmpz, tmpy); // x/y
  mpfq_p_127_735_mul(k, tmpy, P->y, P->t);
  mpfq_p_127_735_mul(k, ZZ, tmpz, tmpy); // x/z

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
    // pseudo add(pm, pp)  -> pp  ;   dble(pm) -> pm
    // Total: 32A + 16P + 9S

    KShadamard(k, pm);					// 8A
    mpfq_p_127_735_mul(k, tmpy, pm->y, KS->y0p);	
    mpfq_p_127_735_mul(k, tmpz, pm->z, KS->z0p);
    mpfq_p_127_735_mul(k, tmpt, pm->t, KS->t0p);	// 3P
    
    KShadamard(k, pp);					// 8A

    mpfq_p_127_735_mul(k, pp->x, pp->x, pm->x);
    mpfq_p_127_735_mul(k, pp->y, pp->y, tmpy);
    mpfq_p_127_735_mul(k, pp->z, pp->z, tmpz);
    mpfq_p_127_735_mul(k, pp->t, pp->t, tmpt);		// 4P
    
    KShadamard(k, pp);					// 8A

    mpfq_p_127_735_sqr(k, pp->x, pp->x);
    mpfq_p_127_735_sqr(k, pp->y, pp->y);
    mpfq_p_127_735_sqr(k, pp->z, pp->z);
    mpfq_p_127_735_sqr(k, pp->t, pp->t);		// 4S

    mpfq_p_127_735_mul(k, pp->y, pp->y, YY);
    mpfq_p_127_735_mul(k, pp->z, pp->z, ZZ);
    mpfq_p_127_735_mul(k, pp->t, pp->t, TT);		// 3P

    mpfq_p_127_735_sqr(k, pm->x, pm->x);		// 1S

    mpfq_p_127_735_mul(k, pm->y, pm->y, tmpy); 
    mpfq_p_127_735_mul(k, pm->z, pm->z, tmpz);
    mpfq_p_127_735_mul(k, pm->t, pm->t, tmpt);		// 3P

    KShadamard(k, pm);					// 8A
    
    mpfq_p_127_735_sqr(k, pm->x, pm->x);
    mpfq_p_127_735_sqr(k, pm->y, pm->y); 
    mpfq_p_127_735_sqr(k, pm->z, pm->z);
    mpfq_p_127_735_sqr(k, pm->t, pm->t);		// 4S

    mpfq_p_127_735_mul(k, pm->y, pm->y, KS->y0);
    mpfq_p_127_735_mul(k, pm->z, pm->z, KS->z0);
    mpfq_p_127_735_mul(k, pm->t, pm->t, KS->t0);	// 3P
    if (swap) {
      tmp = pp; pp = pm; pm = tmp;
    }
  }

  KScopy(k, res, pm);
  KSclear(k, Pm);
  KSclear(k, Pp);
 
  mpfq_p_127_735_clear(k, &YY);
  mpfq_p_127_735_clear(k, &ZZ);
  mpfq_p_127_735_clear(k, &TT);
  mpfq_p_127_735_clear(k, &tmpy);
  mpfq_p_127_735_clear(k, &tmpz);
  mpfq_p_127_735_clear(k, &tmpt);
}


int main(int argc, char** argv) {
  mpz_t key;
  // field and dst_field are the same for this field
  mpfq_p_127_735_field k;
  KSpoint res, base_point;
  KSparam KS;
  int i;

  mpfq_p_127_735_field_init(k);

  if (argc != 6) {
    fprintf(stderr, "usage: %s key base_point\n", argv[0]);
    fprintf(stderr, "    key        is the secret key (an integer < 2^254)\n");
    fprintf(stderr, "    base_point is the point to multiply\n");
    fprintf(stderr, "    base_point must be of the form  1 y z t\n");
    fprintf(stderr, "    (integers less than 2^127, whitespace separated.\n");
    return 1;
  }

  // KS parameters.
  mpfq_p_127_735_init(k, &(KS->y0 ));
  mpfq_p_127_735_init(k, &(KS->z0 ));
  mpfq_p_127_735_init(k, &(KS->t0 ));
  mpfq_p_127_735_init(k, &(KS->y0p));
  mpfq_p_127_735_init(k, &(KS->z0p));
  mpfq_p_127_735_init(k, &(KS->t0p));

  mpfq_p_127_735_sscan(k, KS->y0, "86208552985914662648361214299883935423");
  mpfq_p_127_735_sscan(k, KS->z0, "160053938517731349632395585267160595069");
  mpfq_p_127_735_sscan(k, KS->t0, "35005564474699507747312683600916451858");
  mpfq_p_127_735_sscan(k, KS->y0p, "94814796580219064497014986095768528928");
  mpfq_p_127_735_sscan(k, KS->z0p, "42902767594179849850407630572137072504");
  mpfq_p_127_735_sscan(k, KS->t0p, "22524084758416781578372604087642334537");

  mpz_init_set_str(key, argv[1], 10);
  KSinit(k, base_point);
  mpfq_p_127_735_sscan(k, base_point->x, argv[2]);
  mpfq_p_127_735_sscan(k, base_point->y, argv[3]);
  mpfq_p_127_735_sscan(k, base_point->z, argv[4]);
  mpfq_p_127_735_sscan(k, base_point->t, argv[5]);
  
  KSinit(k, res);
  for (i = 0; i < 1000; ++i) {
    KSmul(k, res, base_point, key, KS);
  }

  mpfq_p_127_735_inv(k, res->x, res->x);
  mpfq_p_127_735_mul(k, res->y, res->y, res->x);
  mpfq_p_127_735_mul(k, res->z, res->z, res->x);
  mpfq_p_127_735_mul(k, res->t, res->t, res->x);
  mpfq_p_127_735_set_ui(k, res->x, 1UL);

  KSprint(k, res); printf("\n");

  mpfq_p_127_735_clear(k, &(KS->y0 ));
  mpfq_p_127_735_clear(k, &(KS->z0 ));
  mpfq_p_127_735_clear(k, &(KS->t0 ));
  mpfq_p_127_735_clear(k, &(KS->y0p));
  mpfq_p_127_735_clear(k, &(KS->z0p));
  mpfq_p_127_735_clear(k, &(KS->t0p));

  KSclear(k, base_point);
  KSclear(k, res);
  mpfq_p_127_735_field_clear(k);
  mpz_clear(key);
  return 0; 
}

#if 0
---------------------------------------------------------------------
Some magma code for testing
---------------------------------------------------------------------

// file kummer.mag available at http://www.loria.fr/~gaudry/publis/kummer.mag
load "kummer.mag";
p := 2^127-735;
a := GF(p)!1;
b := GF(p)!104737609498996807573042644460938049128;
c := GF(p)!149790188288476750369734729103725046598;
d := GF(p)!129048219867477581895670028479253045173;
KS := KummerSurface(a,b,c,d);
P := [ GF(p)| 1, 62246801537368306179529093039701638695, 75239908759044524808779541669076670071, 159480394070211047952510054793822670545];
print [x^2 : x in P] ; // the C-code works with squares of coordinates.
Q := MulKS(P, 258762358962359786, KS);
z := Q[1];
print [(x/z)^2 : x in Q] ; // the C-code works with squares of coordinates.

#endif


