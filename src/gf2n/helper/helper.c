#include "wmat.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

unsigned int shipped_width = 0;
unsigned int macro = 1;

void xmul_mod(unsigned int * a, const unsigned int * p, unsigned int n)
{
	unsigned int pop = a[n-1];
	unsigned int i;
	memmove(a + 1, a, (n-1) * sizeof(unsigned int));
	a[0] = 0;
	if (!pop)
		return;
	for(i = 0 ; i < n ; i++) {
		a[i] ^= p[i];
	}
}

void in_print_one_row(struct wmat * mat, unsigned int i, mp_size_t wd)
{
	unsigned int xl = LIMBS_PER_ROW(mat->n);
	const mp_limb_t * data = mat->rows + (i * xl);
	unsigned int j;

	if (wd <= GMP_LIMB_BITS) {
		for(j = 0 ; j < xl ; j++) {
			mp_limb_t w = data[j];
			if (wd == GMP_LIMB_BITS) {
				printf("0x%lxUL, ", w);
			} else if (2 * wd == GMP_LIMB_BITS) {
				printf("0x%lxUL, ",
						w & ((1UL << wd) - 1));
				if (mat->n > (xl - 1) * 64 + wd)
					printf("0x%lxUL, ", w >> wd);
			}
		}
	} else if (wd == 2 * GMP_LIMB_BITS) {
		for(j = 0 ; j < xl ; j+=2) {
			mp_limb_t wl = data[j];
			mp_limb_t wh = 0UL;
			if (j < xl - 1)
				wh = data[j + 1];
			if (wh) {
				printf("0x%lx%08lxUL, ", wh, wl);
			} else {
				printf("0x%lxUL, ", wl);
			}
		}
	}
}

void print_one_row(const char * table_name,
		struct wmat * mat, unsigned int i, mp_size_t wd)
{
	if (macro)
		printf("#define %s\t", table_name);
	printf("{ ");
	in_print_one_row(mat, i, wd);
	printf("}\n");
}

void in_print_one_matrix(struct wmat * mat, mp_size_t wd)
{
	unsigned int i;
	for(i = 0 ; i < mat->n ; i++) {
		printf("\t{ ");
		in_print_one_row(mat, i, wd);
		printf("},");
		if (macro)
			printf("\t\\");
		printf("\n");
	}
}

void print_one_matrix(const char * table_name,
		struct wmat * mat, mp_size_t wd)
{
	if (macro)
		printf("#define %s\t\\", table_name);
	printf("\n");
	in_print_one_matrix(mat, wd);
	if (macro)
		printf("\t/* end of %s */\n", table_name);
}

void print_definition_row(const char * table_name, struct wmat * mat, unsigned int i)
{
	if (shipped_width) {
		print_one_row(table_name, mat, i, shipped_width);
	} else if (mat->n <= 32) {
		print_one_row(table_name, mat, i, 32);
	} else {
		if (macro) {
			printf("/* definition of %s */\n", table_name);
		} else {
			printf("\n");
		}
		printf("#if (GMP_LIMB_BITS == 32)\n");
		print_one_row(table_name, mat, i, 32);
		printf("#elif (GMP_LIMB_BITS == 64)\n");
		print_one_row(table_name, mat, i, 64);
		printf("#endif	/* %s */\n", table_name);
	}

	if (macro)
		printf("\n");
}

void print_definition_matrix(const char * table_name, struct wmat * mat)
{
	if (shipped_width) {
		print_one_matrix(table_name, mat, shipped_width);
	} else if (mat->n <= 32) {
		print_one_matrix(table_name, mat, 32);
	} else {
		if (macro) {
			printf("/* definition of %s */\n", table_name);
		} else {
			printf("\n");
		}
		printf("#if (GMP_LIMB_BITS == 32)\n");
		print_one_matrix(table_name, mat, 32);
		printf("#elif (GMP_LIMB_BITS == 64)\n");
		print_one_matrix(table_name, mat, 64);
		printf("#endif	/* %s */\n", table_name);
	}

	if (macro)
		printf("\n");
}

int main(int argc, char * argv[])
{
	int i;
	unsigned int * p;
	unsigned int * a;
	unsigned int n, n1;
	int ship_sqrt = 0;
	int ship_sqrt_t = 0;
	int ship_as = 0;

	if (argc <= 1) {
		fprintf(stderr, "Usage: ./helper <coeffs>\n");
		exit(1);
	}

	n = atoi(argv[1]);
	p = malloc(n * sizeof(unsigned int));
	a = malloc(n * sizeof(unsigned int));
	memset(p, 0, n * sizeof(unsigned int));
	memset(a, 0, n * sizeof(unsigned int));
	n1 = n;
	for(i = 2 ; i < argc ; i++) {
		unsigned int k;
		if (strcmp(argv[i], "SQRT_TABLE") == 0) {
			ship_sqrt = 1;
			continue;
		}
		if (strcmp(argv[i], "SQRT_T") == 0) {
			ship_sqrt_t = 1;
			continue;
		}
		if (strcmp(argv[i], "ARTIN_SCHREIER_TABLE") == 0) {
			ship_as = 1;
			continue;
		}
		if (strcmp(argv[i], "nomacro") == 0) {
			macro = 0;
			continue;
		}
		if (strncmp(argv[i], "w=", 2) == 0) {
			shipped_width = atoi(argv[i] + 2);
			continue;
		}

		k = atoi(argv[i]);
		if (!i) continue;
		if (k >= n1) {
			fprintf(stderr,
				"Coefficients must be in decreasing order\n");
			exit(1);
		}
		p[k] = 1;
	}
	struct wmat * mat_s = wmat_zero(n, n);
	a[0] = 1;
	for(i = 0 ; i < n ; i++) {
		unsigned int j;
		for(j = 0 ; j < n ; j++) {
			wmat_set(mat_s, i, j, a[j]);
		}
		xmul_mod(a, p, n);
		xmul_mod(a, p, n);
	}

	if (ship_as) {
		struct wmat * mat_m = wmat_copy(mat_s);
		wmat_add_ident(mat_m);

		struct wmat* mat_nt = wmat_zero(n, n-1);
		{
			struct wmat* mat_n = wmat_zero(n-1, n);
			wmat_vsubmat(mat_n, mat_m, 0, 1, n-1);
			wmat_transpose(mat_nt, mat_n);
			wmat_free(mat_n);
		}

		struct wmat* mat_t = wmat_zero(n, n);
		{
			wmat_row_echelon(mat_t, mat_nt);
			struct wmat* mat_t2 = wmat_zero(n, n);
			wmat_vsubmat(mat_t2, mat_t, 0, n-1, 1);
			wmat_vsubmat(mat_t2, mat_t, 1, 0, n-1);
			wmat_transpose(mat_t, mat_t2);
			wmat_free(mat_t2);
		}

		print_definition_matrix("_MPFQ_GF2N_ARTIN_SCHREIER_TABLE", mat_t);

		wmat_free(mat_t);
		wmat_free(mat_nt);
		wmat_free(mat_m);
	}
	
	if (ship_sqrt_t) {
		struct wmat * mat_sinv = wmat_zero(n, n);
		wmat_row_echelon(mat_sinv, mat_s);

		print_definition_row("_MPFQ_GF2N_SQRT_OF_T", mat_sinv, 1);

		wmat_free(mat_sinv);
	}

	if (ship_sqrt) {
		struct wmat * mat_sinv = wmat_zero(n, n);
		wmat_row_echelon(mat_sinv, mat_s);

		print_definition_matrix("_MPFQ_GF2N_SQRT_TABLE", mat_sinv);

		wmat_free(mat_sinv);
	}

	wmat_free(mat_s);
	
	free(a);
	free(p);
	return 0;
}

