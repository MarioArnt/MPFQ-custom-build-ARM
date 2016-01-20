/*
 * Purpose: implement a Kummer cryptosystem on GF(2^127)
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <gmp.h>

#include "mpfq/mpfq_2_113.h"

// Kummer arithmetic.

typedef struct {
  mpfq_2_113_elt x;
  mpfq_2_113_elt y;
  mpfq_2_113_elt z;
  mpfq_2_113_elt t;
} KSpoint_struct;

typedef KSpoint_struct KSpoint[1];
typedef KSpoint_struct * dst_KSpoint;
typedef const KSpoint_struct * src_KSpoint;

typedef struct {
  mpfq_2_113_elt beta;    // actually there inverses!
  mpfq_2_113_elt gamma;
  mpfq_2_113_elt delta;
} KSparam_struct;

typedef KSparam_struct KSparam[1];
typedef const KSparam_struct * src_KSparam;

//--------------------

static void KSinit(mpfq_2_113_field k, dst_KSpoint P) {
  mpfq_2_113_init(k, &(P->x));
  mpfq_2_113_init(k, &(P->y));
  mpfq_2_113_init(k, &(P->z));
  mpfq_2_113_init(k, &(P->t));
}

static void KSclear(mpfq_2_113_field k, dst_KSpoint P) {
  mpfq_2_113_clear(k, &(P->x));
  mpfq_2_113_clear(k, &(P->y));
  mpfq_2_113_clear(k, &(P->z));
  mpfq_2_113_clear(k, &(P->t));
}

static void KScopy(mpfq_2_113_field k, dst_KSpoint Q, src_KSpoint P) {
  mpfq_2_113_set(k, Q->x, P->x);
  mpfq_2_113_set(k, Q->y, P->y);
  mpfq_2_113_set(k, Q->z, P->z);
  mpfq_2_113_set(k, Q->t, P->t);
}

static void KSdouble(mpfq_2_113_field k, dst_KSpoint Q, src_KSpoint P, 
    src_KSparam KS) {
  mpfq_2_113_elt tmp1, tmp2, tmp3, tmp4;

  mpfq_2_113_init(k, &tmp1); mpfq_2_113_init(k, &tmp2);
  mpfq_2_113_init(k, &tmp3); mpfq_2_113_init(k, &tmp4);

  mpfq_2_113_mul(k, tmp1, P->x, P->t);
  mpfq_2_113_mul(k, tmp2, P->y, P->z);
  mpfq_2_113_add(k, tmp1, tmp1, tmp2);   // tmp1 = x*t + y*z
  mpfq_2_113_add(k, tmp2, P->x, P->y);
  mpfq_2_113_add(k, tmp3, P->z, P->t);
  mpfq_2_113_mul(k, tmp2, tmp2, tmp3);
  mpfq_2_113_add(k, tmp2, tmp2, tmp1);   // tmp2 = x*z + y*t = (x+y)(z+t) + xt + yz
  mpfq_2_113_add(k, tmp3, P->x, P->z);
  mpfq_2_113_add(k, tmp4, P->y, P->t);
  mpfq_2_113_mul(k, tmp3, tmp3, tmp4);
  mpfq_2_113_add(k, tmp3, tmp3, tmp1);   // tmp3 = x*y + z*t = (x+z)(y+t) + xt + yz
  mpfq_2_113_add(k, Q->t, P->z, P->t);
  mpfq_2_113_add(k, Q->t, Q->t, P->x);
  mpfq_2_113_add(k, Q->t, Q->t, P->y);   // Q.t = x+y+z+t
  mpfq_2_113_sqr(k, Q->x, tmp1);
  mpfq_2_113_sqr(k, Q->y, tmp2);
  mpfq_2_113_sqr(k, Q->z, tmp3);
  mpfq_2_113_sqr(k, Q->t, Q->t);
  mpfq_2_113_sqr(k, Q->t, Q->t);

  // The following will be mul_ui
  mpfq_2_113_mul(k, Q->y, Q->y, KS->beta);
  // mpfq_2_113_mul(k, Q->z, Q->z, KS->gamma);
  mpfq_2_113_mul(k, Q->t, Q->t, KS->delta);
  
  mpfq_2_113_clear(k, &tmp1); mpfq_2_113_clear(k, &tmp2);
  mpfq_2_113_clear(k, &tmp3); mpfq_2_113_clear(k, &tmp4);
}

void KSprint(mpfq_2_113_field k, src_KSpoint P) {
  mpfq_2_113_print(k, P->x); printf(" ");
  mpfq_2_113_print(k, P->y); printf(" ");
  mpfq_2_113_print(k, P->z); printf(" ");
  mpfq_2_113_print(k, P->t); 
}

// scalar multiplication on Surf2_113
// key is 4 limb long.
void KSmul(mpfq_2_113_field k, dst_KSpoint res, src_KSpoint P, mpz_t key,
    src_KSparam KS) {
  KSpoint Pm, Pp;
  mpfq_2_113_elt L1, L2, L3, L4, M1, M2, M3, N;
  mpfq_2_113_elt YY, ZZ, TT;
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

  mpfq_2_113_init(k, &L1);
  mpfq_2_113_init(k, &L2);
  mpfq_2_113_init(k, &L3);
  mpfq_2_113_init(k, &L4);
  mpfq_2_113_init(k, &M1);
  mpfq_2_113_init(k, &M2);
  mpfq_2_113_init(k, &M3);
  mpfq_2_113_init(k, &N);

  mpfq_2_113_init(k, &YY);
  mpfq_2_113_init(k, &ZZ);
  mpfq_2_113_init(k, &TT);

#if 1
  mpfq_2_113_mul(k, L1, P->y, P->z);
  mpfq_2_113_mul(k, L2, L1, P->t);
  mpfq_2_113_inv(k, L2, L2);
  mpfq_2_113_mul(k, L2, L2, P->x);
  mpfq_2_113_mul(k, TT, L2, L1); // x/t
  mpfq_2_113_mul(k, L1, P->z, P->t);
  mpfq_2_113_mul(k, YY, L2, L1); // x/y
  mpfq_2_113_mul(k, L1, P->y, P->t);
  mpfq_2_113_mul(k, ZZ, L2, L1); // x/z
#else
  mpfq_2_113_inv(k, YY, P->y);
  mpfq_2_113_mul(k, YY, YY, P->x);
  mpfq_2_113_inv(k, ZZ, P->z);
  mpfq_2_113_mul(k, ZZ, ZZ, P->x);
  mpfq_2_113_inv(k, TT, P->t);
  mpfq_2_113_mul(k, TT, TT, P->x);
#endif

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

    // pseudo-add(pm,pp) -> pp
    // Cost : 26A + 11P + 4S
    mpfq_2_113_add(k, L1, pm->x, pm->y);
    mpfq_2_113_add(k, L2, pm->z, pm->t);
    mpfq_2_113_add(k, N, L1, L2);
    mpfq_2_113_add(k, M1, N, pm->x);
    mpfq_2_113_add(k, M2, N, pm->z);
    mpfq_2_113_add(k, M3, N, pm->y);

    mpfq_2_113_add(k, L1, pp->x, pp->y);
    mpfq_2_113_add(k, L2, pp->z, pp->t);
    mpfq_2_113_add(k, L3, L1, L2);
    mpfq_2_113_mul(k, N, L3, N);
    mpfq_2_113_add(k, L3, L2, pp->y);
    mpfq_2_113_mul(k, M1, L3, M1);
    mpfq_2_113_add(k, L3, L1, pp->t);
    mpfq_2_113_mul(k, M2, L3, M2);
    mpfq_2_113_add(k, L3, L2, pp->x);
    mpfq_2_113_mul(k, M3, L3, M3);

    mpfq_2_113_mul(k, L1, pm->x, pp->x);
    mpfq_2_113_mul(k, L2, pm->y, pp->y);
    mpfq_2_113_mul(k, L3, pm->z, pp->z);
    mpfq_2_113_mul(k, L4, pm->t, pp->t);

    mpfq_2_113_add(k, L1, L1, L4);
    mpfq_2_113_add(k, pp->x, L1, N);
    mpfq_2_113_add(k, pp->x, M2, pp->x);
    mpfq_2_113_add(k, pp->x, M3, pp->x);


    mpfq_2_113_add(k, pp->y, L2, L4);
    mpfq_2_113_add(k, pp->y, N, pp->y);
    mpfq_2_113_add(k, pp->y, M2, pp->y);
    mpfq_2_113_add(k, pp->y, M1, pp->y);

    mpfq_2_113_add(k, pp->z, L3, L4);
    mpfq_2_113_add(k, pp->z, N, pp->z);
    mpfq_2_113_add(k, pp->z, M3, pp->z);
    mpfq_2_113_add(k, pp->z, M1, pp->z);

    mpfq_2_113_add(k, L2, L2, L3);
    mpfq_2_113_add(k, pp->t, L1, L2);

    mpfq_2_113_sqr(k, pp->x, pp->x);
    mpfq_2_113_sqr(k, pp->y, pp->y);
    mpfq_2_113_sqr(k, pp->z, pp->z);
    mpfq_2_113_sqr(k, pp->t, pp->t); 

    mpfq_2_113_mul(k, pp->y, pp->y, YY);
    mpfq_2_113_mul(k, pp->z, pp->z, ZZ);
    mpfq_2_113_mul(k, pp->t, pp->t, TT); 

    // double pm
    // Cost : 10A + 4P + 5S + 3 sP
    KSdouble(k, pm, pm, KS);

    if (swap) {
      tmp = pp; pp = pm; pm = tmp;
    }
  }

  KScopy(k, res, pm);
  KSclear(k, Pm);
  KSclear(k, Pp);
 
  mpfq_2_113_clear(k, &YY);
  mpfq_2_113_clear(k, &ZZ);
  mpfq_2_113_clear(k, &TT);
  mpfq_2_113_clear(k, &L1);
  mpfq_2_113_clear(k, &L2);
  mpfq_2_113_clear(k, &L3);
  mpfq_2_113_clear(k, &L4);
  mpfq_2_113_clear(k, &M1);
  mpfq_2_113_clear(k, &M2);
  mpfq_2_113_clear(k, &M3);
  mpfq_2_113_clear(k, &N);
}


int main(int argc, char** argv) {
  mpz_t key;
  mpfq_2_113_field k;
  KSpoint res, base_point;
  KSparam KS;
  int i;

  mpfq_2_113_field_init(k); 
  { 
      mp_limb_t io_base = 10;
      mpfq_2_113_field_setopt(k, MPFQ_IO_TYPE, &io_base);
  }

  if (argc != 6) {
    fprintf(stderr, "usage: %s key base_point\n", argv[0]);
    fprintf(stderr, "    key        is the secret key (an integer < 2^254)\n");
    fprintf(stderr, "    base_point is the point to multiply\n");
    fprintf(stderr, "    base_point must be of the form  1 y z t\n");
    fprintf(stderr, "    (integers less than 2^127, whitespace separated.\n");
    return 1;
  }

  // KS parameters.
  mpfq_2_113_init(k, &(KS->beta ));
  mpfq_2_113_init(k, &(KS->gamma ));
  mpfq_2_113_init(k, &(KS->delta ));

  mpfq_2_113_sscan(k, KS->beta, "111");
  mpfq_2_113_sscan(k, KS->gamma, "1");
  mpfq_2_113_sscan(k, KS->delta, "7");

  mpz_init_set_str(key, argv[1], 10);
  KSinit(k, base_point);
  mpfq_2_113_sscan(k, base_point->x, argv[2]);
  mpfq_2_113_sscan(k, base_point->y, argv[3]);
  mpfq_2_113_sscan(k, base_point->z, argv[4]);
  mpfq_2_113_sscan(k, base_point->t, argv[5]);
  
  KSinit(k, res);
  for (i = 0; i < 1000; ++i) {
    KSmul(k, res, base_point, key, KS);
  }

  mpfq_2_113_inv(k, res->x, res->x);
  mpfq_2_113_mul(k, res->y, res->y, res->x);
  mpfq_2_113_mul(k, res->z, res->z, res->x);
  mpfq_2_113_mul(k, res->t, res->t, res->x);
  // set x to 1.
  (res->x)[0] = 1UL;
  for (i = 1; i < 2; ++i)   // WARNING, this 2 is sizeof(elt)
    (res->x)[i] = 0UL;

  KSprint(k, res); printf("\n");

  mpfq_2_113_clear(k, &(KS->alpha ));
  mpfq_2_113_clear(k, &(KS->beta ));
  mpfq_2_113_clear(k, &(KS->gamma ));

  KSclear(k, res);
  KSclear(k, base_point);
  mpz_clear(key);
  return 0; 
}

#if 0

PP<t> := PolynomialRing(GF(2));
Fq<T> := ext<GF(2) | t^113 + t^9 + 1>;

alpha := Fq!1;
beta := Fq!IntegerToChar2Polynomial(111); 
gamma := Fq!IntegerToChar2Polynomial(1); 
delta := Fq!IntegerToChar2Polynomial(7); 

KS := KummerSurface(1/alpha, 1/beta, 1/gamma, 1/delta);
P := [Fq!1,
  Fq!IntegerToChar2Polynomial(1238984503090426823044878048926908),
  Fq!IntegerToChar2Polynomial(7545492644397800203664618119174637),
  Fq!IntegerToChar2Polynomial(2148163187067577342061514160110689)];

Q := MulKS(P, 5913369630930828585928565323096496294573733703322036623241333262897, KS);
xx := Q[1];
Q := [ x/xx : x in Q];
[ Seqint([ Integers()!x :x in Eltseq(Q[i])], 2) : i in [1..4]];

-------------------------------------------------


PP<t> := PolynomialRing(GF(2));
Fq<T> := ext<GF(2) | t^113 + t^9 + 1>;

alpha := Fq!1;
beta := Fq!IntegerToChar2Polynomial(362); 
gamma := Fq!IntegerToChar2Polynomial(8); 
delta := Fq!IntegerToChar2Polynomial(4); 

s1 := 128297922647580798;
s2 := 14667058352183929882124797110497945;
N := 107839786668602560510989861787234722304661688161677455652999169708824;
Nt := 107839786668602557846346258908922352418552171586506888445423933280796;

KS := KummerSurface(1/alpha, 1/beta, 1/gamma, 1/delta);
P := RandomPointKS(KS);

IsZeroKS(MulKS(P,N,KS), KS);


alpha := Fq!1;
beta := Fq!IntegerToChar2Polynomial(523); 
gamma := Fq!IntegerToChar2Polynomial(10); 
delta := Fq!IntegerToChar2Polynomial(4); 

s1 := 13554019874354448;
s2 := 11175035395977637041846967964322085;
N := 107839786668602559319421049976336950389874360201746472565640968203244;
Nt := 107839786668602559037915070719820072649152003223304023589251985146316;

KS := KummerSurface(1/alpha, 1/beta, 1/gamma, 1/delta);

P := RandomPointKS(KS); IsZeroKS(MulKS(P,N,KS), KS), IsZeroKS(MulKS(P,Nt,KS), KS);

// other choices: 651 5 9  or  594 4 6





// curve generated using:

load "Recherche/theta/char2/kummer.mag";
PP<t> := PolynomialRing(GF(2));
Fq<T> := ext<GF(2) | t^113 + t^9 + 1>;

PP<x> := PolynomialRing(Fq);
alpha := Fq!1;

for b := 653 to 712 do
  printf "b = %o\n", b;
  beta := Fq!IntegerToChar2Polynomial(b);
  be := 1/beta;
  for c := 1 to 10 do
    if c eq b then continue; end if;
    gamma := Fq!IntegerToChar2Polynomial(c);
    ga := 1/gamma;
    for d := 1 to 10 do
      if d eq b then continue; end if;
      if d eq c then continue; end if;
      delta := Fq!IntegerToChar2Polynomial(d);
      de := 1/delta;

      f0 := ga/be/de;
      f1 := (be+ga)^2/be/ga/de;
      f2 := be*ga/de;
      f3 := f2;

      h := x*(x+1);
      f := h*(f3*x^3 + f2*x^2 + f1*x + f0);
      test, C := IsHyperellipticCurve([f,h]);
      if not test then continue; end if;
      Z := Numerator(ZetaFunction(C));
      N := Evaluate(Z, 1);
      Nt := Evaluate(Z, -1);
      okN := IsPrime(N div 4) or ((N mod 8 eq 0) and IsPrime(N div 8));
      okNt := IsPrime(Nt div 4) or ((Nt mod 8 eq 0) and IsPrime(Nt div 8));
      if  okN and okNt then
        if N eq Nt then
          printf "Found but s1 = 0!!! %o %o %o\n",b,c,d;
	else
	  printf "Found  %o %o %o\n",b,c,d;
	end if;
      end if;
    end for;
  end for;
end for;


#endif


