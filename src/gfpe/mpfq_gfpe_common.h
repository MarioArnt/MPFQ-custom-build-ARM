#ifndef MPFQ_GFPE_COMMON_H_
#define MPFQ_GFPE_COMMON_H_

#include "gmp.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "mpfq/mpfq.h"

#ifdef __cplusplus
extern "C" {
#endif

/***  A general type for (all possible?) extensions of prime fields ***/

// Info for Tonelli-Shanks. 
// Let q be the field cardinality (odd).
// Write q - 1 = h*2^e, with h odd.
// A value of e=0 means that the data is not initialized
typedef struct {
    int e;
    void * z; // a Generator of the 2-Sylow, castable into an elt.
    mp_limb_t * hh; // (h-1)/2, stored as an mpn of length hhl.
    size_t hhl;
} ts_info_struct_e;


typedef struct {
    mpfq_p_field kbase;
    unsigned long deg;
    void * P; // castable into a poly over kbase, defining poly
    void * invrevP; // castable into a poly, modulo helper
    ts_info_struct_e ts_info; // sqrt helper, same type as for gfp
} mpfq_pe_field_struct;

typedef mpfq_pe_field_struct mpfq_pe_field[1];
typedef const mpfq_pe_field_struct * mpfq_pe_src_field;
typedef mpfq_pe_field_struct * mpfq_pe_dst_field;


#ifdef __cplusplus
}
#endif

#endif	/* MPFQ_GFPE_COMMON_H_ */
