#include <stdio.h>
#include <stdlib.h>
#include "emu.h"
#include "frontend/frontend.h"
#include "cpu.h"
#include "cpuexec.h"
#include "memory.h"
#include "machine.h"
#include "video/screen.h"
#include "utils.h"
#include "monitor.h"
#include "video/chroni.h"


int main(int argc, char *argv[]) {
	if (frontend_init(argc, argv)) return 1;

	screen_init();

	machine_init();

	utils_load_xex("../asm/os/6502os.xex");
	//utils_load_xex("../asm/test/test_sprites.xex");
	//utils_load_xex("../asm/test/test_atari.xex");
	//utils_load_xex("../asm/test/test_spectrum.xex");
	//utils_load_xex("../asm/test/graphics_3.xex");
	utils_load_xex("../asm/test/mode_4.xex");

	v_cpu *cpu;

	cpu = cpu_init(CPU_M6502);
	cpuexec_init(cpu);

	chroni_init();
	int i=0;
	monitor_enable(cpu);
	while(frontend_running() && i<4) {
		chroni_run_frame();
		screen_update();
		frontend_process_events();
		// frontend_sleep(1);
		// i++;
	}
	utils_dump_mem(0x0000, 0x0400);
	utils_dump_mem(0x2000, 0x0400);
	utils_dump_mem(0xA800, 0X0400);
	// utils_dump_mem(0xF000, 0X0FFF);
	frontend_done();

	return 0;
}
