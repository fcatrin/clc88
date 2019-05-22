#include <stdio.h>
#include <string.h>
#include "emu.h"
#include "trace.h"
#include "utils.h"
#include "bus.h"
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
			"A:%02X X:%02X Y:%02X P:%02X S:%02X",
			cpu->get_reg(M6502_A),
			cpu->get_reg(M6502_X),
			cpu->get_reg(M6502_Y),
			cpu->get_reg(M6502_P),
			cpu->get_reg(M6502_S)
		);
	}
	printf("%s\n", register_info);
}

static unsigned dump_code(unsigned addr) {
	char disasm[100];
	unsigned next_addr = cpu->disasm(addr, disasm);

	char multi_byte[20]  = "";
	char single_byte[20] = "";
	int instructions = next_addr - addr;
	for(int i=0; i<3; i++) {
		if (i<instructions) {
			sprintf(single_byte, "%02X ", bus_read16(addr+i));
			strcat(multi_byte, single_byte);
		} else {
			strcat(multi_byte, "   ");
		}
	}

	char code[100];
	sprintf(code, "%04X %s  %s", addr, multi_byte, utils_str2upper(disasm));
	printf("%s\n", code);
	return next_addr;
}

static unsigned disasm(unsigned addr, int lines) {
	for(int i=0; i<lines; i++) {
		addr = dump_code(addr);
	}
	return addr;
}

#define MAX_LINE_SIZE 1000

void monitor_enter() {
	char line[MAX_LINE_SIZE+1];

	bool trace_was_enabled = trace_enabled;
	trace_enabled = FALSE;

	unsigned dasm_start = cpu->get_pc();

	dump_registers();
	dump_code(cpu->get_pc());

	while(TRUE) {
		printf(">");
		fgets(line, MAX_LINE_SIZE, stdin);
		if (!strcmp(line, "") || !strcmp(line,"s")) {
			dump_registers();
			dump_code(cpu->get_pc());
			continue;
		} else if (!strcmp(line, "d")) {
			dasm_start = disasm(dasm_start, 16);
		} else if (!strcmp(line, "da")) {
			dasm_start = disasm(cpu->get_pc(), 16);
		} else if (utils_starts_with(line, "d ")) {
			char *saddr = utils_trim(line+1);

			unsigned addr;
			sscanf(saddr, "%x", &addr);
			dasm_start = disasm(addr, 16);
		} else if (!strcmp(line, "g")) {
			is_enabled = FALSE;
			break;
		}
	}

	trace_enabled = trace_was_enabled;
}
