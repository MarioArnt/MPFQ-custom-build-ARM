#include "bitlinalg.h"
#include <string.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

/* This layer is slightly low-level, and allows arbitrary striding */

static inline
void xor_row(mp_limb_t * dst, const mp_limb_t * src, int l)
{
	int i;
	for(i = 0 ; i < l ; i++) {
		dst[i] ^= src[i];
	}
}

#ifndef	MIN
#define	MIN(a,b)	(((a) < (b)) ? (a) : (b))
#endif

void add_ident(mp_limb_t *matrix, int xl, int m, int n)
{
	int i;
	for(i = 0 ; i < MIN(m,n) ; i++) {
		xor_bit(matrix + i * xl, i);
	}
}

int
scan1(const mp_limb_t * p, mp_size_t s)
{
	const mp_limb_t * q = p;
	int c = 0;
	for(; s > 0 && (*q == 0UL); s--, q++);
	// [p..q[ has been looked up and confirmed == 0.
	if (s != 0) {
		c = __builtin_ctzl(*q);
	}
	return c + (q - p) * GMP_LIMB_BITS;
}

/*
 * make matrix mat into echelon form (destructively).
 * matrix size is m * n, stride is xl. returns the rank.
 * t is such that mat_{echelon} = y * mat_{original}
 * yl is the striding of t.
 *
 * t must be allocated (m * m)
 */

int row_echelon(
		mp_limb_t * t, int yl,
		mp_limb_t * mat, int xl, int m, int n)
{
	int dimk;
	int i0;
	int * fs;
	unsigned int mp;
	int i, j;
	mp_limb_t mask;
	const mp_limb_t * pivot;
	mp_limb_t * trav;

	if (t) {
		memset(t, 0, m * yl * sizeof(mp_limb_t));
		add_ident(t, yl, m, m);
	}

	/* first non-zero element in row */
	fs = malloc(m * sizeof(int));

	/* dimension of the kernel so far */
	dimk = 0;

	mp = 0;
	mask = 1UL;

	for (i = 0; i < m; i++) {
		/* zero rows will yield fs >= n */
		fs[i] = scan1(mat + i * xl, xl);
	}

	for (j = 0; j < n; j++, mask <<= 1) {
		if (mask == 0UL) {
			mp++;
			mask = 1UL;
		}

		/* find a row with a 1 in column j */
		for (i0 = 0; i0 < m && fs[i0] != j; i0++);

		/* i0 == m indicates that an element of the
		 * (right) nullspace has been found */
		if (i0 == m) {
			dimk++;
			continue;
		}

		pivot = mat + i0 * xl + mp;

		/* Cancel this coefficient in the column */
		for (i = 0, trav = mat + mp; i < m; i++, trav += xl) {
			if ((mask & *trav) && (i != i0)) {
				if (t)
					xor_row(t + i * yl, t + i0 * yl, yl);
				xor_row(trav, pivot, xl - mp);
				fs[i] = scan1(trav - mp, xl);
				/* it's not possible to start at trav
				 * exactly, because we may encounter a
				 * first set bit before the current
				 * column index */
			}
		}
	}

	free(fs);

	return n - dimk;
}

/* same thing, but sorts rows */
int row_echelon_sorted(
		mp_limb_t * t, int yl,
		mp_limb_t * mat, int xl, int m, int n)
{
	int r, i, j;
	mp_limb_t * tmp = NULL;
	mp_limb_t * tmp_mat;

	if (t) {
		tmp = malloc(m * yl * sizeof(mp_limb_t));
	}

	tmp_mat = malloc(m * xl * sizeof(mp_limb_t));
	memcpy(tmp_mat, mat, m * xl * sizeof(mp_limb_t));

	r = row_echelon(tmp, yl, tmp_mat, xl, m, n);
	if (t) {
		memset(t, 0, m * yl * sizeof(mp_limb_t));
	}
	memset(mat, 0, m * xl * sizeof(mp_limb_t));

	for (i = 0; i < m; i++) {
		j = scan1(tmp_mat + i * xl, xl);
		if (j >= n)
			continue;
		/* this row in position j will yield a 1 in position (j, j) */
		if (t) memcpy(t + j * yl, tmp + i * yl, yl * sizeof(mp_limb_t));
		xor_row(mat + j * xl, tmp_mat + i * xl, xl);
	}

	if (t)
		free(tmp);
	free(tmp_mat);

	return r;
}

/* returns a basis of the kernel of m. t must be big enough to hold the
 * kernel (up to n), the striding of t is yl, and t has n columns.
 */
int right_nullspace(
		mp_limb_t * t, int yl,
		mp_limb_t * mat, int xl, int m, int n)
{
	int dimk = n - row_echelon(NULL, 0, mat, xl, m, n);
	int i, j;
	int * eliminated;
	int * elim;
	int k;

	memset(t, 0, dimk * yl * sizeof(mp_limb_t));

	elim = malloc(m * sizeof(int));
	memset(elim, 0, m * sizeof(int));

	eliminated = malloc(n * sizeof(int));
	memset(eliminated, 0, n * sizeof(int));

	k = 0;
	
	for (i = 0; i < m; i++) {
		int j = scan1(mat + i * xl, xl);
		if (j < n) {
			elim[i] = j;
			eliminated[j] = 1;
			/* fprintf(stderr, "elim[%d]=%d\n",i,j); */
		}
	}

	k = 0;
	for(j = 0 ; j < n ; j++) {
		if (eliminated[j])
			continue;
		or_bit(t + k * yl, j);
		for(i = 0 ; i < m ; i++) {
			if (test_bit(mat + i * xl, j))
				or_bit(t + k * yl, elim[i]);
		}
		k++;
	}

	free(eliminated);
	free(elim);

	return dimk;
}

void multiply(mp_limb_t * r, int zl,
		const mp_limb_t * a, int xl,
		const mp_limb_t * b, int yl, int m, int n, int p)
{
	int i, j;
	memset(r, 0, m * zl * sizeof(mp_limb_t));
	for(i = 0 ; i < m ; i++) {
		for(j = 0 ; j < n ; j++) {
			if (test_bit(a + i * xl, j))
				xor_row(r + i * zl, b + j * yl, MIN(yl, zl));
		}
	}
}
void add(mp_limb_t * r, int zl,
		const mp_limb_t * a, int xl,
		const mp_limb_t * b, int yl, int m, int n)
{
	int i;
	memset(r, 0, m * zl * sizeof(mp_limb_t));
	for(i = 0 ; i < m ; i++) {
		xor_row(r + i * zl, a + i * xl, MIN(xl, zl));
		xor_row(r + i * zl, b + i * yl, MIN(yl, zl));
	}
}
