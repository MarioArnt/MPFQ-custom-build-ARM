#ifndef WRAPPER_H_
#define WRAPPER_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>
#include <gmp.h>

#include "bitlinalg.h"

#define	LIMBS_PER_ROW(n) (((n) + GMP_LIMB_BITS - 1) / GMP_LIMB_BITS)
#define	LIMBS_PER_MATRIX(n) ((n) * LIMBS_PER_ROW(n))

struct wmat {
	int m;
	int n;
	/* valid c99 ; must be allocated anyway. */
	mp_limb_t rows[];
};

struct wmat * wmat_alloc(int, int);
void wmat_free(struct wmat *);
struct wmat * wmat_copy(const struct wmat *);
#define MATRIX_BYTES(m,n) ((m) * LIMBS_PER_ROW((n)) * sizeof(mp_limb_t) + sizeof(struct wmat))
int wmat_row_echelon(struct wmat * dst, struct wmat * src);
int wmat_right_nullspace(struct wmat * dst, struct wmat * src);
void wmat_multiply(struct wmat * r, const struct wmat * a, const struct wmat * b);
void wmat_add(struct wmat * r, const struct wmat * a, const struct wmat * b);
void wmat_add_ident(struct wmat * r);
static inline void
wmat_sub(struct wmat * r, const struct wmat * a, const struct wmat * b)
{
	wmat_add(r,a,b);
}
static inline void
wmat_sub_ident(struct wmat * r)
{
	wmat_add_ident(r);
}
struct wmat * wmat_zero(int, int);
struct wmat * wmat_one(int, int);
void wmat_bitflip(struct wmat *);
int wmat_trace(const struct wmat *);
void wmat_transpose(struct wmat * dst, const struct wmat * src);
void wmat_submat(struct wmat * dst, const struct wmat * src,
		int i1, int j1,
		int i0, int j0,
		int m, int n);
void wmat_vsubmat(struct wmat * dst, const struct wmat * src,
		int i1, int i0, int m);
void wmat_print(FILE *, const struct wmat *);

static inline void
wmat_set(struct wmat * dst, int i, int j, unsigned int x)
{
	if (x) {
		or_bit(dst->rows + i * LIMBS_PER_ROW(dst->n), j);
	} else {
		clear_bit(dst->rows + i * LIMBS_PER_ROW(dst->n), j);
	}
}
static inline unsigned int
wmat_get(const struct wmat * dst, int i, int j)
{
	return test_bit(dst->rows + i * LIMBS_PER_ROW(dst->n), j);
}

#ifdef __cplusplus
}
#endif

#endif	/* WRAPPER_H_ */
