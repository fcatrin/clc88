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

#define WORD(a, b) (a + (b << 8))

#define TRUE  1
#define FALSE 0

#define BOOLSTR(x) ((x) ? "true" : "false")

typedef UINT8 bool;

/*
 * Versions of GNU C earlier that 2.7 appear to have problems with the
 * __attribute__ definition of UNUSEDARG, so we act as if it was not a
 * GNU compiler.
 */

#ifdef __GNUC__
#if (__GNUC__ < 2) || ((__GNUC__ == 2) && (__GNUC_MINOR__ <= 7))
#define UNUSEDARG
#else
#define UNUSEDARG __attribute__((__unused__))
#endif
#else
#define UNUSEDARG
#endif



/*
 * Use __builtin_expect on GNU C 3.0 and above
 */
#ifdef __GNUC__
#if (__GNUC__ < 3)
#define UNEXPECTED(exp)	(exp)
#else
#define UNEXPECTED(exp)	 __builtin_expect((exp), 0)
#endif
#else
#define UNEXPECTED(exp)	(exp)
#endif

#if defined(MIXER_USE_CLIPPING)
#define MAME_CLAMP_SAMPLE(a) \
   if ((int16_t)a != a) \
      a = (a >> 31) ^ 0x7FFF
#else
#define MAME_CLAMP_SAMPLE(a) ((void)0)
#endif

#endif
