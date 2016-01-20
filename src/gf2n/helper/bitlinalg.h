#ifndef BITLINALG_H_
#define BITLINALG_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <gmp.h>

static inline void xor_bit(mp_limb_t *c, int t)
{
	c[t / GMP_LIMB_BITS] ^= 1UL << (t % GMP_LIMB_BITS);
}

static inline void or_bit(mp_limb_t *c, int t)
{
	c[t / GMP_LIMB_BITS] |= 1UL << (t % GMP_LIMB_BITS);
}

static inline void clear_bit(mp_limb_t *c, int t)
{
	c[t / GMP_LIMB_BITS] &= ~(1UL << (t % GMP_LIMB_BITS));
}

static inline int test_bit(const mp_limb_t *c, int t)
{
	return (c[t / GMP_LIMB_BITS] >> (t % GMP_LIMB_BITS)) & 1UL;
}


int row_echelon(mp_limb_t *, int, mp_limb_t *, int, int, int);
int row_echelon_sorted(mp_limb_t *, int, mp_limb_t *, int, int, int);
int right_nullspace(mp_limb_t *, int, mp_limb_t *, int, int, int);
void multiply(mp_limb_t *, int, const mp_limb_t *, int, const mp_limb_t *, int, int, int, int);
void add(mp_limb_t *, int, const mp_limb_t *, int, const mp_limb_t *, int, int, int);
void add_ident(mp_limb_t *matrix, int xl, int m, int n);
#ifdef __cplusplus
}
#endif

#endif	/* BITLINALG_H_ */
