#include <stdio.h>
#include "emu.h"
#include "memory.h"
#include "video/cvpu.h"
#include "trace.h"

/*
 * right now there are no other devices connected to the bus, only memory
 */

UINT8 bus_read16(UINT16 addr) {
	LOGV("bus read %04X", addr);
	if (addr >= CVPU_MEM_START && addr <= CVPU_MEM_END) {
		return cvpu_vram_read(addr - CVPU_MEM_START);
	}
	return mem_readmem16(addr);
}
void  bus_write16(UINT16 addr, UINT8 value) {
	LOGV("bus write %04X = %02X", addr, value);
	if (addr >= CVPU_START && addr <= CVPU_END) {
		cvpu_register_write(addr - CVPU_START, value);
	} else if (addr >= CVPU_MEM_START && addr <= CVPU_MEM_END) {
		cvpu_vram_write(addr - CVPU_MEM_START, value);
	} else {
		mem_writemem16(addr, value);
	}
}

void  bus_write(UINT16 addr, UINT8 *values, UINT16 size) {
	for(int i=0; i<size && addr+i < 0x10000; i++) {
		bus_write16(addr+i, values[i]);
	}
}

