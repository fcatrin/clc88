#include <stdio.h>
#include "emu.h"
#include "cpu.h"
#include "memory.h"
#include "machine.h"

UINT8 test_code_6502[] = { 0xA9, 0x92, 0x8D, 0x01, 0x07, 0x4C, 0x00, 0x06};
/*   * = 0x600
 * LOOP:
 *   LDA #0x92
 *   STA 0x701
 *   JMP LOOP
 */


UINT8 test_code_z80[] = {0x3e, 0x29, 0x32, 0x02, 0x07, 0xc3, 0x00, 0x00};
/*   * = 0x000
 * LOOP:
 *   LD A, #0x29
 *   LD (0x702), A
 *   JMP LOOP
 */


int main(int argc, char *argv[]) {
	machine_init();

	mem_write(0x600, test_code_6502, 8);
	mem_write(0x000, test_code_z80,  8);

	// 6502 reset vector
	mem_writemem16(0xFFFC, 0x00);
	mem_writemem16(0xFFFD, 0x06);

	v_cpu cpu;

	cpu = cpu_init(CPU_M6502);
	cpu.reset();
	cpu.run(100);

	cpu = cpu_init(CPU_Z80);
	cpu.reset();
	cpu.run(100);

	printf("result on memory 0x701 : 0x%02X\n", mem_readmem16(0x701));
	printf("result on memory 0x702 : 0x%02X\n", mem_readmem16(0x702));

	return 0;
}
