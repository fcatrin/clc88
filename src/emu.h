#ifndef _EMU_H
#define _EMU_H

#include <stdint.h>
#include <stdarg.h>

#define logerror(...) fprintf (stderr, __VA_ARGS__)

typedef uint8_t                                         UINT8;
typedef int8_t                                          INT8;
typedef uint16_t                                        UINT16;
typedef int16_t                                         INT16;
typedef uint32_t                                        UINT32;
typedef int32_t                                         INT32;
typedef int64_t                                         INT64;
typedef uint64_t                                        UINT64;

typedef union {
#ifdef MSB_FIRST
        struct { UINT8 h3,h2,h,l; } b;
        struct { UINT16 h,l; } w;
#else
        struct { UINT8 l,h,h2,h3; } b;
        struct { UINT16 l,h; } w;
#endif
        UINT32 d;
}       PAIR;

typedef struct  {
	int sample_rate;
} MachineDef;

extern MachineDef *Machine;

#endif
