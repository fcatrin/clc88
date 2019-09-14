#include "emu.h"
#include "keyb.h"
#include "frontend/frontend.h"

#define LOGTAG "KEYB"
#ifdef TRACE_KEYB
#define TRACE
#endif
#include "trace.h"

UINT8 keyb_register_read(UINT8 index) {
	return frontend_keyb_reg_read(index);
}
