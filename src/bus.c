#include <stdio.h>
#include "emu.h"
#include "memory.h"
#include "storage.h"
#include "video/chroni.h"
#include "sound.h"
#include "keyb.h"
#include "bus.h"

/*
 * system memory map
 *
 * 6502:
 *   0000 - 00FF : Page Zero
 *   0100 - 01FF : Stack
 *   0200 - 8FFF : Free memory
 *   9000 - 9FFF : Memory Mapped Registers (see below) (4KB)
 *   A000 - DFFF : VRAM Window (16KB)
 *   E000 - FFFF : OS ROM (8KB)
 *
 *   9000 - 907F : Chroni registers
 *
 */

#define LOGTAG "BUS"
#ifdef TRACE_BUS
#define TRACE
#endif
#include "trace.h"

UINT8 bus_read16(UINT16 addr) {
	UINT8 retvalue = 0;
	if (addr >= CHRONI_START && addr <= CHRONI_END) {
		retvalue = chroni_register_read(addr - CHRONI_START);
	} else if (addr >= CHRONI_MEM_START && addr <= CHRONI_MEM_END) {
		retvalue = chroni_vram_read(addr - CHRONI_MEM_START);
	} else if (addr >= STORAGE_START && addr <= STORAGE_END) {
		retvalue = storage_register_read(addr - STORAGE_START);
	} else if (addr >= KEYB_START && addr <= KEYB_END) {
		retvalue = keyb_register_read(addr - KEYB_START);
	} else {
		retvalue = mem_readmem16(addr);
	}
	LOGV(LOGTAG, "bus read %04X = %02X", addr, retvalue);
	return retvalue;
}
void  bus_write16(UINT16 addr, UINT8 value) {
	if (addr <0xA000 || addr >= 0xD000) {
		LOGV(LOGTAG, "bus write %04X = %02X", addr, value);
	}
	if (addr >= CHRONI_START && addr <= CHRONI_END) {
		chroni_register_write(addr - CHRONI_START, value);
	} else if (addr >= CHRONI_MEM_START && addr <= CHRONI_MEM_END) {
		chroni_vram_write(addr - CHRONI_MEM_START, value);
	} else if (addr >= STORAGE_START && addr <= STORAGE_END) {
		storage_register_write(addr - STORAGE_START, value);
	} else if (addr >= SOUND_POKEY_START && addr <= SOUND_POKEY_END) {
		sound_register_write(addr - SOUND_POKEY_START, value);
	} else {
		mem_writemem16(addr, value);
	}
}

void  bus_write(UINT16 addr, UINT8 *values, UINT16 size) {
	for(int i=0; i<size && addr+i < 0x10000; i++) {
		bus_write16(addr+i, values[i]);
	}
}

