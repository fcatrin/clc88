#include "emu.h"
#include "memory.h"

/*
 * right now there are no other devices connected to the bus, only memory
 */

UINT8 bus_read16(UINT16 addr) {
	return mem_readmem16(addr);
}
void  bus_write16(UINT16 addr, UINT8 value) {
	mem_writemem16(addr, value);
}
