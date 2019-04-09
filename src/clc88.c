#include <stdio.h>
#include "emu.h"
#include "cpu.h"
#include "memory.h"

UINT8 test_code[] = { 0xA9, 0x92, 0x8D, 0x01, 0x07, 0x76, 0x00, 0x06};
/*
 * LOOP:
 *   LDA #0x92
 *   STA #0x701
 *   JMP LOOP
 */

int main(int argc, char *argv[]) {

	mem_write(0x600, test_code, 8);
	mem_writemem16(0xFFFC, 0x00);
	mem_writemem16(0xFFFD, 0x06);

	v_cpu cpu = cpu_init(CPU_M6502);
	cpu.reset();

	cpu.run(100);

	printf("result on memory 0x701 : %02X", mem_readmem16(0x701));

	return 0;
}
