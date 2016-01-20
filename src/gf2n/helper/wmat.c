#include "wmat.h"
#include "bitlinalg.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct wmat * wmat_alloc(int m, int n)
{
	struct wmat * res;
	res = (struct wmat *) malloc(MATRIX_BYTES(m, n));
	res->m = m;
	res->n = n;
	return res;
}
struct wmat * wmat_zero(int m, int n)
{
	struct wmat * res = wmat_alloc(m, n);
	memset(res->rows, 0, m * LIMBS_PER_ROW(n) * sizeof(mp_limb_t));
	return res;
}
struct wmat * wmat_one(int m, int n)
{
	struct wmat * res = wmat_zero(m, n);
	wmat_add_ident(res);
	/*
	int i;
	for(i = 0 ; i < m && i < n ; i++) {
		or_bit(res->rows + i * LIMBS_PER_ROW(n), i);
	}
	*/
	return res;
}

struct wmat * wmat_copy(const struct wmat * m)
{
	struct wmat * res = (struct wmat *) malloc(MATRIX_BYTES(m->m,m->n));
	memcpy(res, m, MATRIX_BYTES(m->m, m->n));
	return res;
}

void wmat_free(struct wmat * p)
{
	p->m = 0;
	p->n = 0;
	free(p);
}

int wmat_row_echelon(struct wmat * dst, struct wmat * src)
{
	// fprintf(stderr, "m=%d\n", src->m);
	// fprintf(stderr, "n=%d\n", src->n);
	return row_echelon_sorted(
			dst->rows, LIMBS_PER_ROW(src->m),
			src->rows, LIMBS_PER_ROW(src->n),
			src->m, src->n);
}

int wmat_right_nullspace(struct wmat * dst, struct wmat * src)
{
	return right_nullspace(
			dst->rows, LIMBS_PER_ROW(src->n),
			src->rows, LIMBS_PER_ROW(src->n),
			src->m, src->n);
}

void wmat_multiply(struct wmat * r,
		const struct wmat * a, const struct wmat * b)
{
	return multiply(r->rows, LIMBS_PER_ROW(b->n),
			a->rows, LIMBS_PER_ROW(a->n),
			b->rows, LIMBS_PER_ROW(b->n),
			a->m, a->n, b->n);
}

void wmat_add(struct wmat * r,
		const struct wmat * a, const struct wmat * b)
{
	return add(r->rows, LIMBS_PER_ROW(a->n),
			a->rows, LIMBS_PER_ROW(a->n),
			b->rows, LIMBS_PER_ROW(a->n),
			a->m, a->n);
}

void wmat_add_ident(struct wmat * r)
{
	return add_ident(r->rows, LIMBS_PER_ROW(r->n), r->m, r->n);
}

void wmat_bitflip(struct wmat * a)
{
	int i;
	// fprintf(stderr, "bitflipping %d*%d\n", a->m, a->n);
	for(i = 0 ; i < a->m * LIMBS_PER_ROW(a->n) ; i++) {
		a->rows[i] = ~ a->rows[i];
	}
}

int wmat_trace(const struct wmat * a)
{
	int i;
	mp_limb_t res = 0;
	for(i = 0 ; i < a->m ; i++) {
		res ^= (test_bit(a->rows + i * LIMBS_PER_ROW(a->n), i)) != 0;
	}
	return res;
}

/* slow, lame */
void wmat_transpose(struct wmat * dst, const struct wmat * src)
{
	int i, j;
	int xl, yl;
	xl = LIMBS_PER_ROW(src->n);
	yl = LIMBS_PER_ROW(src->m);
	memset(dst->rows, 0, src->n * yl * sizeof(mp_limb_t));
	for(i = 0 ; i < src->m ; i++) {
		for(j = 0 ; j < src->n ; j++) {
			if (test_bit(src->rows + i * xl, j))
				or_bit(dst->rows + j * yl, i);
		}
	}
}

void wmat_submat(struct wmat * dst, const struct wmat * src,
		int i1, int j1,
		int i0, int j0,
		int m, int n)
{
	int i, j;
	int xl, yl;
	xl = LIMBS_PER_ROW(src->n);
	yl = LIMBS_PER_ROW(dst->n);
	memset(dst->rows, 0, dst->m * yl * sizeof(mp_limb_t));
	for(i = 0 ; i < m ; i++) {
		for(j = 0 ; j < n ; j++) {
			clear_bit(dst->rows + (i+i1) * yl, j+j1);
			if (test_bit(src->rows + (i+i0) * xl, j+j0))
				or_bit(dst->rows + (i+i1) * yl, j+j1);
		}
	}
}

void wmat_vsubmat(struct wmat * dst, const struct wmat * src,
		int i1, int i0, int m)
{
	int xl = LIMBS_PER_ROW(src->n);
	memcpy(dst->rows + i1 * xl, src->rows + i0 * xl, m * xl * sizeof(mp_limb_t));
}

#if 0
void wmat_hsubmat(struct wmat * dst, const struct wmat * src,
		int j1, int j0, int n)
{
	int i;
	for(i = 0 ; i < src->m ; i++) {
		mp_limb_t * q = dst->rows + i * LIMBS_PER_ROW(dst->n);
		const mp_limb_t * p = src->rows + i * LIMBS_PER_ROW(src->n);
		// copy bits [j0..j0+n[ to position [j1..j1+n[
	memcpy(dst->rows + i1 * xl, src->rows + i0 * xl, m * xl * sizeof(mp_limb_t));
}
#endif


void wmat_print(FILE * f, const struct wmat * src)
{
	int i,j;
	int xl = LIMBS_PER_ROW(src->n);
	for(i = 0 ; i < src->m ; i++) {
		printf("[");
		for(j = 0 ; j < src->n ; j++) {
			printf(" %d", test_bit(src->rows + i*xl, j) != 0);
		}
		printf(" ]\n");
	}
}
