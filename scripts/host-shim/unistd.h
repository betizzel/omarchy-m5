/* SPDX-License-Identifier: GPL-2.0 */
/*
 * <unistd.h> wrapper for macOS host-tool builds: supplies the Linux-only
 * copy_file_range(2) used by usr/gen_init_cpio.c. Implemented with
 * pread/pwrite so explicit offsets behave like Linux.
 */
#ifndef _OMARCHY_SHIM_UNISTD_H
#define _OMARCHY_SHIM_UNISTD_H

#include_next <unistd.h>

#include <sys/types.h>
#include <stddef.h>
#include <errno.h>

static inline ssize_t omarchy_shim_copy_file_range(int fd_in, off_t *off_in,
						   int fd_out, off_t *off_out,
						   size_t len, unsigned int flags)
{
	char buf[65536];
	size_t done = 0;

	if (flags)
		return (errno = EINVAL), -1;

	while (done < len) {
		size_t chunk = len - done;
		ssize_t n;
		if (chunk > sizeof(buf))
			chunk = sizeof(buf);

		if (off_in)
			n = pread(fd_in, buf, chunk, *off_in + (off_t)done);
		else
			n = read(fd_in, buf, chunk);
		if (n <= 0)
			return done ? (ssize_t)done : n;

		if (off_out) {
			if (pwrite(fd_out, buf, (size_t)n, *off_out + (off_t)done) != n)
				return done ? (ssize_t)done : -1;
		} else {
			if (write(fd_out, buf, (size_t)n) != n)
				return done ? (ssize_t)done : -1;
		}
		done += (size_t)n;
	}

	if (off_in)
		*off_in += (off_t)done;
	if (off_out)
		*off_out += (off_t)done;
	return (ssize_t)done;
}

#define copy_file_range omarchy_shim_copy_file_range

#endif
