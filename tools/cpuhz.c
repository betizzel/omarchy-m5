// SPDX-License-Identifier: MIT
/*
 * cpuhz - estimate the running core's clock: a chain of dependent adds
 * retires one per cycle on Apple cores, so iterations per CPU-second ~= Hz
 * (thread CPU time, so a busy machine does not skew it).
 * Build: aarch64-linux-gnu-gcc -O2 -static -o build/cpuhz tools/cpuhz.c
 */
#include <stdint.h>
#include <stdio.h>
#include <time.h>

static double now(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_THREAD_CPUTIME_ID, &ts);	/* CPU time: immune to other load */
	return ts.tv_sec + ts.tv_nsec * 1e-9;
}

int main(void)
{
	const uint64_t n = 1000000000ull;	/* x8 adds per iteration below */
	uint64_t x = 0;
	double t0 = now();
	for (uint64_t i = 0; i < n; i++)
		asm volatile("add %0, %0, #1\n\tadd %0, %0, #1\n\tadd %0, %0, #1\n\tadd %0, %0, #1\n\t"
			     "add %0, %0, #1\n\tadd %0, %0, #1\n\tadd %0, %0, #1\n\tadd %0, %0, #1"
			     : "+r"(x));
	double dt = now() - t0;
	printf("%.0f MHz (%.2f s, x=%llu)\n", 8.0 * n / dt / 1e6, dt, (unsigned long long)x);
	return 0;
}
