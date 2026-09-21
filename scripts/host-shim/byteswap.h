/* SPDX-License-Identifier: GPL-2.0 */
/* <byteswap.h> stand-in for macOS host-tool builds (glibc header). */
#ifndef _OMARCHY_SHIM_BYTESWAP_H
#define _OMARCHY_SHIM_BYTESWAP_H

#include <libkern/OSByteOrder.h>

#define bswap_16(x)  OSSwapInt16(x)
#define bswap_32(x)  OSSwapInt32(x)
#define bswap_64(x)  OSSwapInt64(x)

#endif
