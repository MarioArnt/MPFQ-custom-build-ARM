#ifndef TIMING_H_
#define TIMING_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

#include <sys/time.h>
#include <sys/resource.h>
#define HAVE_microseconds
static inline uint64_t microseconds()
{
	struct rusage res[1];
	getrusage(RUSAGE_SELF,res);
	uint64_t r;
	r  = (uint64_t) res->ru_utime.tv_sec;
	r *= (uint64_t) 1000000UL;
	r += (uint64_t) res->ru_utime.tv_usec;
	return r;
}

#if defined(__GNUC__)
#if defined (__i386__)
#define	HAVE_cputicks
static inline uint64_t cputicks()
{
	uint64_t r;
        __asm__ __volatile__(
                "rdtsc\n\t"
                "movl %%eax,(%0)\n\t"
                "movl %%edx,4(%0)\n\t"
                : /* no output */
                : "S"(&r)
                : "eax", "edx", "memory");
	return r;
}
#elif defined(__x86_64__)
#define HAVE_cputicks
static inline uint64_t cputicks()
{
	uint64_t r;
        __asm__ __volatile__(
                "rdtsc\n\t"
                "shlq $32, %%rdx\n\t"
                "orq %%rdx, %%rax\n\t"
                : "=a"(r)
                : 
                : "rdx");
	return r;
}
#endif
#endif

#ifdef __cplusplus
}
#endif

#endif	/* TIMING_H_ */
