#include <stdio.h>
#include <string.h>
#include "emu.h"
#include "trace.h"
#include "cpu.h"
#include "cpu/m6502/m6502.h"
#include "monitor.h"

bool is_enabled = FALSE;
v_cpu *cpu;

void monitor_enable(v_cpu *monitor_cpu) {
	is_enabled = TRUE;
	cpu = monitor_cpu;
}

void monitor_disable() {
	is_enabled = FALSE;
}

bool monitor_is_enabled() {
	return is_enabled;
}

static void dump_registers() {
	char register_info[1000];
	if (cpu->cpuType == CPU_M6502) {
		sprintf(register_info,
			"PC:%04X A:%02X X:%02X Y:%02X P:%02X S:%02X",
			cpu->get_reg(M6502_PC),
			cpu->get_reg(M6502_A),
			cpu->get_reg(M6502_X),
			cpu->get_reg(M6502_Y),
			cpu->get_reg(M6502_P),
			cpu->get_reg(M6502_S)
		);
	}
	printf("%s\n", register_info);
}

void monitor_enter() {
	char line[1000];

	bool trace_was_enabled = trace_enabled;
	trace_enabled = FALSE;

	while(TRUE) {
		dump_registers();
		printf(">");
		scanf("%s", line);
		if (!strcmp(line, "") || !strcmp(line,"s")) {
			continue;
		} else if (!strcmp(line, "g")) {
			is_enabled = FALSE;
			break;
		}
	}

	trace_enabled = trace_was_enabled;
}
