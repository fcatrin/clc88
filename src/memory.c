#include "emu.h"
#include "memory.h"

UINT8 memory[0x10000]; // Addressable 64K

UINT8 mem_readmem16(UINT16 addr) {
	return memory[addr];
}

void  mem_writemem16(UINT16 addr, UINT8 value) {
	memory[addr] = value;
}
void  mem_write(UINT16 addr, UINT8 *values, UINT16 size) {
	for(int i=0; i<size && addr+i < 0x10000; i++) {
		memory[addr+i] = values[i];
	}
}
