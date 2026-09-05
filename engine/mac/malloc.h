/*
 * OpenBOR - http://www.chronocrash.com
 * -----------------------------------------------------------------------
 * Compatibility shim for Apple platforms.
 *
 * Several engine sources use the glibc-only  #include <malloc.h>.  macOS /
 * iOS have no top-level malloc.h; the standard malloc/realloc/free entry
 * points live in <stdlib.h>.  This shim is reached only through the Darwin
 * build (see the "INCS += mac" line in the Makefile), so Linux/Windows
 * builds never see it.
 */
#ifndef OPENBOR_MAC_MALLOC_H
#define OPENBOR_MAC_MALLOC_H

#include <stdlib.h>

#endif /* OPENBOR_MAC_MALLOC_H */
