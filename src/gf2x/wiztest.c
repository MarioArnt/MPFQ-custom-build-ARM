#define	_GNU_SOURCE
#include <stdio.h>
#include <gmp.h>
#include <inttypes.h>
#include "timing.h"
#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include "dump_poly.h"
#include INC

typedef int (*sortfunc_t)(const void * a, const void * b);

/**********************************************************************/
int ntrials_default = 10000;
int nmicros_for_timing = 200 * 1000;
int testing = 0;
int nrep_ticks = 100;
int code_selection = 0;
int selected_codes[1000] = { 0, };


mp_limb_t a[MM] = { 0, };
mp_limb_t b[NN] = { 0, };
mp_limb_t s[MM + NN] = { 0, };
mp_limb_t ref[MM + NN] = { 0, };
char *ref_method = NULL;

int failure = 0;

int verification(const char *method, const char *name)
{
    if (ref_method == NULL) {
	memcpy(ref, s, sizeof(s));
	ref_method = strdup(method);
	return 1;
    }
    if (memcmp(ref, s, sizeof(s)) != 0) {
	printf("ERROR %s (r) != %s (s) [%s]\n", ref_method, method, name);
	fprintf(stderr,"ERROR %s (r) != %s (s) [%s]\n", ref_method, method, name);
	dump_poly("a", MM, GMP_LIMB_BITS, a);
	dump_poly("b", NN, GMP_LIMB_BITS, b);
	dump_poly("r", MM + NN - 1, GMP_LIMB_BITS, ref);
	dump_poly("s", MM + NN - 1, GMP_LIMB_BITS, s);
	failure = 1;
	return 0;
    }
    return 1;
}


#define	TIME(X,ntrials_,tt_,f_) do {			\
        tt_ = f_();					\
        for(int i_ = 0 ; i_ < ntrials_ ; i_++) {	\
                X (s,a,b);				\
        }						\
        tt_ = f_() - tt_;				\
} while (0)

#define	N_TICKS_SAMPLES 200
uint64_t ticks_result[N_TICKS_SAMPLES];

#define TIME_TICKS(X) do {						\
	uint64_t * ptr = &(ticks_result[0]);				\
	for(int i = 0 ; i < N_TICKS_SAMPLES ; i++) {			\
                uint64_t tt;                                            \
                TIME(X, nrep_ticks, tt, cputicks);                      \
                *ptr++ = tt;                                            \
	}								\
} while (0)

int uint64_cmp(const uint64_t * a, const uint64_t * b)
{
    return (*a > *b) - (*a < *b);
}

uint64_t median_of_ticks()
{
    /*
    for(int i = 0 ; i < N_TICKS_SAMPLES ; i++) {
        printf(" %" PRIu64, ticks_result[i]);
    }
    printf("\n");
    */
    qsort(ticks_result, N_TICKS_SAMPLES, sizeof(uint64_t), 
            (sortfunc_t) &uint64_cmp); 
    return ticks_result[N_TICKS_SAMPLES / 2];
}

#define TIME_TICKS_COMPLETE(res_,X) do {        \
    TIME_TICKS(X);                              \
    res_ = median_of_ticks();                   \
} while (0)


#define TIME_microseconds_COMPLETE(res_, X) do {        \
    int ntrials_ = ntrials_default;					\
    double tt_;                                                          \
    for(tt_ = 0 ; tt_ < nmicros_for_timing ; ntrials_ *= tt_ ? 2 : 32) {              \
	TIME(X,ntrials_,tt_,microseconds);				\
    }                                                                   \
    res_ = tt_ / ntrials_;                                                \
} while (0)



#if defined(HAVE_cputicks)
const char * used_unit = "clock cycles";
#define TRY_BACKEND(res_, NAME, X) do {						\
	uint64_t ticks;							\
        res_ = -1;                                                       \
        double tt;                                                      \
	X (s,a,b);							\
	if (!verification(#X, NAME)) break;				\
        TIME_TICKS_COMPLETE(ticks, X);                                  \
        tt = ticks / (double) nrep_ticks;                               \
        printf("%.4f %s\n", tt, NAME);                                  \
        res_ = tt;                                                      \
} while (0)
#else
const char * used_unit = "microseconds";
#define TRY_BACKEND(res_, NAME, X) do {						\
        res_ = -1;                                                       \
	double tt;							\
	X (s,a,b);							\
	if (!verification(#X, NAME)) break;				\
        TIME_microseconds_COMPLETE(tt, X);                              \
        printf("%.4f %s\n", tt, NAME);                                  \
        res_ = tt;                                                      \
} while (0)
#endif

void noop(mp_limb_t * s __attribute__ ((unused)),
	  const mp_limb_t * a __attribute__ ((unused)),
	  const mp_limb_t * b __attribute__ ((unused)))
    __attribute__ ((noinline));
void noop(mp_limb_t * s __attribute__ ((unused)), const mp_limb_t * a
	  __attribute__ ((unused)), const mp_limb_t * b
	  __attribute__ ((unused)))
{
}

/**********************************************************************/

struct perf_record {
    double time;
    const char *name;
    int num;
};

struct xtable {
    struct perf_record *values;
    int alloc;
    int size;
};

struct xtable records_table = { 0, 0, 0, };

void record_one(const char *nm, int num, double res)
{
    if (records_table.size >= records_table.alloc) {
	int x = records_table.alloc;
	x += 32 * !x;
	x *= 2;
	records_table.values = realloc(records_table.values,
				       x * sizeof(struct perf_record));
	records_table.alloc = x;
    }
    records_table.values[records_table.size].time = res;
    records_table.values[records_table.size].name = strdup(nm);
    records_table.values[records_table.size].num = num;
    records_table.size++;
}

int compare_records(const struct perf_record * pa, const struct perf_record * pb)
{
    return (pa->time > pb->time) - (pa->time < pb->time);
}



void sort_records()
{
    qsort((void *) records_table.values,
	  records_table.size, sizeof(struct perf_record),
          (sortfunc_t) &compare_records);
}

void hi_scores()
{
    int i;
    printf("### best functions ###\n");
    for (i = 0; i < records_table.size; i++) {
	printf("%.4f : [%d] %s\n",
	       records_table.values[i].time,
	       records_table.values[i].num,
               records_table.values[i].name);
    }
}

#define TRY(NAME, X) do {						\
    double this_function;						\
    ++codenum;                                                      	\
    if (code_selection && !selected_codes[codenum]) break;              \
    TRY_BACKEND(this_function, NAME, X);				\
    record_one(NAME, codenum, this_function);				\
} while (0)


#if 0
void dump_limb_array(char *name, int n, int s, mp_limb_t * x)
{
    int i;
    /* This mask is valid whenever s < GMP_LIMB_BITS */
    mp_limb_t mask = (~0UL >> (GMP_LIMB_BITS - s));
    printf("%s:", name);
    for (i = 0; i < n; i += s) {
	printf(" %08lx", x[i / s] & mask);
    }
    printf("\n");
}
#endif

void clamp(mp_limb_t * x, int total, int n, int s)
{
    if (n >= s) {
	x += (n / s);
	total -= (n / s);
	n = n % s;
    }
    assert(n < GMP_LIMB_BITS);
    *x &= ((1UL << n) - 1UL);
    for (; --total; *++x = 0);
}


int main(int argc, char *argv[])
{
    int i;

    for (; argc > 1; argv++, argc--) {
	if (strcmp(argv[1], "-t") == 0) {
	    ntrials_default = 2;
	    testing = 1;
	    continue;
	}
	if (strcmp(argv[1], "-n") == 0) {
	    ntrials_default = atoi(argv[2]);
	    argc--, argv++;
	    continue;
	}
	if (strcmp(argv[1], "-s") == 0) {
	    char *ptr;
	    argc--, argv++;
	    for (ptr = argv[1]; *ptr ; ) {
                char * nptr;
                unsigned long c = strtoul(ptr, &nptr, 10);
                if (nptr == ptr) {
                    abort();
                }
                if (c > sizeof(selected_codes)/sizeof(selected_codes[0])) {
                    abort();
                }
                selected_codes[c]=1;
                if (*nptr) {
                    if (*nptr != ',')
                        abort();
                    nptr++;
                }
                ptr = nptr;
	    }
            code_selection=1;
	    continue;
	}
	fprintf(stderr, "Unexpected argument %s\n", argv[1]);
	exit(1);
    }

    printf("Unit: %s\n", used_unit);
    for (i = 0; i < (testing ? 100 : 1); i++) {
	mpn_random(a, MM);
	mpn_random(b, NN);
	clamp(a, MM, MM, GMP_LIMB_BITS);
	clamp(b, NN, NN, GMP_LIMB_BITS);
	memset(s, 0, sizeof(s));
	ref_method = 0;

	int codenum = 0;

	mpfq_wizard_mul_possibilities();
    }

    if (failure) {
	exit(1);
    }

    if (testing) {
	printf("%d tests passed\n", i);
    } else {
	sort_records();
	hi_scores();
    }

    return 0;
}
