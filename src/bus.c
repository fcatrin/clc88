#include <stdio.h>
#include "emu.h"
#include "memory.h"
#include "trace.h"
#include "video/chroni.h"

/*
 * right now there are no other devices connected to the bus, only memory
 */

UINT8 bus_read16(UINT16 addr) {
	LOGV("bus read %04X", addr);
	if (addr >= CHRONI_MEM_START && addr <= CHRONI_MEM_END) {
		return chroni_vram_read(addr - CHRONI_MEM_START);
	}
	return mem_readmem16(addr);
}
void  bus_write16(UINT16 addr, UINT8 value) {
	LOGV("bus write %04X = %02X", addr, value);
	if (addr >= CHRONI_START && addr <= CHRONI_END) {
		chroni_register_write(addr - CHRONI_START, value);
	} else if (addr >= CHRONI_MEM_START && addr <= CHRONI_MEM_END) {
		chroni_vram_write(addr - CHRONI_MEM_START, value);
	} else {
		mem_writemem16(addr, value);
	}
}

void  bus_write(UINT16 addr, UINT8 *values, UINT16 size) {
	for(int i=0; i<size && addr+i < 0x10000; i++) {
		bus_write16(addr+i, values[i]);
	}
}

