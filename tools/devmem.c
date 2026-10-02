// SPDX-License-Identifier: MIT
/*
 * devmem - read (or write) one 32/64-bit MMIO register through /dev/mem.
 *
 *   devmem ADDR [32|64]          read, print 0x... (width default 32)
 *   devmem ADDR 32|64 VALUE      write VALUE, then read back
 *
 * /dev/mem read()/write() only cover RAM on arm64 (MMIO gives EFAULT), so
 * this mmap()s the page, which the kernel maps as device memory. Arch's
 * busybox ships without the devmem applet. Build (static, on the ThinkPad):
 *   aarch64-linux-gnu-gcc -O2 -static -o build/devmem tools/devmem.c
 */
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

int main(int argc, char **argv)
{
	if (argc < 2 || argc > 4) {
		fprintf(stderr, "usage: %s ADDR [32|64] [VALUE]\n", argv[0]);
		return 2;
	}
	uint64_t addr = strtoull(argv[1], NULL, 0);
	int width = argc > 2 ? atoi(argv[2]) : 32;
	if ((width != 32 && width != 64) || addr % (width / 8)) {
		fprintf(stderr, "width must be 32 or 64 and ADDR aligned to it\n");
		return 2;
	}

	long page = sysconf(_SC_PAGESIZE);
	uint64_t base = addr & ~(uint64_t)(page - 1);
	int fd = open("/dev/mem", argc == 4 ? O_RDWR | O_SYNC : O_RDONLY | O_SYNC);
	if (fd < 0) {
		fprintf(stderr, "/dev/mem: %s\n", strerror(errno));
		return 1;
	}
	int prot = PROT_READ | (argc == 4 ? PROT_WRITE : 0);
	void *map = mmap(NULL, page, prot, MAP_SHARED, fd, (off_t)base);
	if (map == MAP_FAILED) {
		fprintf(stderr, "mmap 0x%" PRIx64 ": %s\n", base, strerror(errno));
		return 1;
	}
	volatile void *reg = (volatile char *)map + (addr - base);

	if (argc == 4) {
		uint64_t val = strtoull(argv[3], NULL, 0);
		if (width == 64)
			*(volatile uint64_t *)reg = val;
		else
			*(volatile uint32_t *)reg = (uint32_t)val;
	}
	uint64_t val = width == 64 ? *(volatile uint64_t *)reg : *(volatile uint32_t *)reg;
	printf("0x%0*" PRIx64 "\n", width / 4, val);
	return 0;
}
