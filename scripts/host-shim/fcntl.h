/* SPDX-License-Identifier: GPL-2.0 */
/* <fcntl.h> wrapper for macOS host-tool builds: O_LARGEFILE is a no-op on
 * a 64-bit host. */
#ifndef _OMARCHY_SHIM_FCNTL_H
#define _OMARCHY_SHIM_FCNTL_H

#include_next <fcntl.h>

#ifndef O_LARGEFILE
#define O_LARGEFILE 0
#endif

#endif
