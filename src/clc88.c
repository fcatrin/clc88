#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "emu.h"
#include "frontend/frontend.h"
#include "cpu.h"
#include "cpuexec.h"
#include "memory.h"
#include "machine.h"
#include "storage.h"
#include "video/screen.h"
#include "utils.h"
#include "monitor.h"
#include "video/chroni.h"

static bool arg_monitor_enabled = FALSE;
static bool arg_monitor_stop_on_xex = FALSE;
static char xexfile[1000] = "";

static void emulator_init(int argc, char *argv[]) {
	for(int i=1; i<argc; i++) {
		if (!strcmp(argv[i], "-M")) arg_monitor_enabled = TRUE;
		else if (!strcmp(argv[i], "-m")) arg_monitor_stop_on_xex = TRUE;
		else {
			strcpy(xexfile, argv[i]);
		}
	}
}

static void emulator_load(char *filename) {
	char buffer[1000];
	sprintf(buffer, "%s.xex", filename);
	utils_load_xex(buffer);
	sprintf(buffer, "%s.lst", filename);
	monitor_source_read_file(buffer);
}

int main(int argc, char *argv[]) {
	if (frontend_init(argc, argv)) return 1;

	emulator_init(argc, argv);

	screen_init();
	storage_init();
	machine_init();

	monitor_source_init();

	emulator_load("../asm/6502/os/6502os");
	//utils_load_xex("../asm/test/test_sprites.xex");
	//utils_load_xex("../asm/test/test_atari.xex");
	//utils_load_xex("../asm/test/test_spectrum.xex");
	//utils_load_xex("../asm/test/graphics_3.xex");
	if (strlen(xexfile) > 0) {
		emulator_load(xexfile);
	}

	v_cpu *cpu;

	cpu = cpu_init(CPU_M6502);
	monitor_init(cpu);
	if (arg_monitor_enabled) {
		monitor_enable();
	}

	if (arg_monitor_stop_on_xex) {
		monitor_breakpoint_set(0x2000);
	}

	cpuexec_init(cpu);

	chroni_init();
	int i=0;
	while(frontend_running() && i<4) {
		chroni_run_frame();
		screen_update();
		frontend_process_events();
		// frontend_sleep(1);
		// i++;
	}
	// utils_dump_mem(0x0000, 0x0400);
	// utils_dump_mem(0x2000, 0x0400);
	// utils_dump_mem(0xA800, 0X0400);
	// utils_dump_mem(0xF000, 0X0FFF);
	storage_done();
	frontend_done();

	return 0;
}
