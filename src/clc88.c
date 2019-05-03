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
#include "video/chroni.h"

int main(int argc, char *argv[]) {
	if (frontend_init(argc, argv)) return 1;

	screen_init();

	machine_init();

	utils_load_xex("../asm/os/6502os.xex");
	utils_load_xex("../asm/test/test_atari.xex");
	//utils_load_xex("../asm/os/test_spectrum.xex");

	v_cpu cpu;

	cpu = cpu_init(CPU_M6502);
	cpuexec_init(cpu);

	chroni_init();
	int i=0;
	while(frontend_running() && i<3) {
		chroni_run_frame();
		screen_update();
		frontend_process_events();
		utils_dump_mem(0, 32);
	}
	frontend_done();

	return 0;
}
