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
#include "sound.h"
#include "system.h"

#define LOGTAG "COMPY"
#ifdef TRACE_COMPY
#define TRACE
#endif
#include "trace.h"

static bool arg_monitor_enabled = FALSE;
static bool arg_monitor_stop_on_boot = FALSE;
static char xexfile[1000] = "";

static void emulator_init(int argc, char *argv[]) {
	for(int i=1; i<argc; i++) {
		if (!strcmp(argv[i], "-M")) arg_monitor_enabled = TRUE;
		else if (!strcmp(argv[i], "-m")) arg_monitor_stop_on_boot = TRUE;
		else if (argv[i][0] == '-') i++;
		else {
			strcpy(xexfile, argv[i]);
		}
	}
}

static void emulator_load(char *filename) {
	char buffer[1000];
	sprintf(buffer, "%s.xex", filename);
	utils_load_xex(buffer);
	sprintf(buffer, "%s.xex.lst", filename);
	monitor_source_read_file(buffer);
}

void compy_init(int argc, char *argv[]) {

	emulator_init(argc, argv);

	screen_init();
	storage_init(argc, argv);
	machine_init();
	sound_init();

	monitor_source_init();

	emulator_load("../bin/asm/6502/os/rom");

	// only if testing ROM embedded xex code
	// utils_load_bin("../asm/6502/test/modes/mode_0_attribs.xex", 0xe000);

	if (strlen(xexfile) > 0) {
		emulator_load(xexfile);
	}

	v_cpu *cpu;

	cpu = cpu_init(CPU_M6502);
	monitor_init(cpu);
	if (arg_monitor_enabled) {
		monitor_enable();
	}

	if (arg_monitor_stop_on_boot) {
		monitor_breakpoint_set(0x700);
	}

	cpuexec_init(cpu);

	chroni_init();

}

/*
 cpu base frequency = 3125000 (3.125Mhz)
 multipliers for 6.25Mhz, 12.5Mhz, 25Mhz, 50Mhz and 100Mhz

 Pixel clock vs CPU clock using the cpu base frequency follows:

 Using rtl/compy/chroni_vga_mode.vh as a reference for 320x240 resolution:
 Horizontal: 400 pixel clocks, 80 blank and 320 display
 Vertical:   262 scanlines, 22 blank 240 display

 CPU Clocks:
 262 real scanlines @ 60Hz ~ 200 cycles per scanline

 On each scanline: 80 blank + 320 display pixel clocks => 0.5 cycles per pixel clock =>
 40 cycles on blank, 160 cycles on display

 blank cycles are distributed evenly on front and back porch for simplicity

 As for sound samples: 44100 samples per second / 60 frames per second = 735 samples per frame
 samples per scanline = 735/262

 real time is:
 60 frames per second  (16666 microseconds)
 240 scanlines per frame (69 microseconds)


*/

float samples_per_scanline = 735.0f / 262;
int cpu_cycles_multiplier = 1;
int cpu_cycles_front_porch = 20;
int cpu_cycles_back_porch = 20;
int cpu_cycles_display = 160;

float microseconds_per_scanline = 1000000.0f / 60.0f / 262.0f;

void compy_run_frame() {
	chroni_frame_start();
	do {
		int cpu_cycles;
		chroni_scanline_back_porch();
		cpu_cycles = cpu_cycles_multiplier * cpu_cycles_front_porch;
		CPU_GO(cpu_cycles);
		chroni_scanline_display();
		cpu_cycles = cpu_cycles_multiplier * cpu_cycles_display;
		CPU_GO(cpu_cycles);
		chroni_scanline_front_porch();
		cpu_cycles = cpu_cycles_multiplier * cpu_cycles_back_porch;
		CPU_GO(cpu_cycles);

		sound_process(samples_per_scanline);
		system_run((UINT32)microseconds_per_scanline);
		cpuexec_irq(system_has_irq() ? 1 : 0);
	} while (!chroni_frame_is_complete());
	chroni_frame_end();
}

void compy_run() {
	compy_run_frame();
	screen_update();
}

void compy_done() {
	storage_done();
	sound_done();
}
