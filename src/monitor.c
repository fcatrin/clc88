#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "emu.h"
#include "trace.h"
#include "utils.h"
#include "bus.h"
#include "cpu.h"
#include "cpu/m6502/m6502.h"
#include "frontend/frontend.h"
#include "monitor.h"

bool is_enabled = FALSE;
bool is_step    = FALSE;
bool is_stop_at_addr = FALSE;
bool is_stop_at_ret  = FALSE;
unsigned stop_at_addr = 0;

v_cpu *cpu;

#define MAX_LINE_SIZE 1000

#define MAX_BREAKPOINTS 100
unsigned breakpoints[MAX_BREAKPOINTS];
unsigned breakpoints_count = 0;

static char *source_lines[0x10000];
static char *source_labels[0x10000];

void monitor_init(v_cpu *monitor_cpu) {
	cpu = monitor_cpu;
}

void monitor_enable() {
	is_enabled = TRUE;
}

void monitor_disable() {
	is_enabled = FALSE;
}

bool monitor_is_enabled() {
	return is_enabled;
}

static unsigned parse_hex(char *s) {
	char *saddr = utils_trim(s);

	unsigned addr;
	sscanf(saddr, "%x", &addr);
	return addr;
}

static void dump_registers() {
	char register_info[1000];
	char flags[100];
	if (cpu->cpuType == CPU_M6502) {
		UINT8 p = cpu->get_reg(M6502_P);
		sprintf(flags, "N%c V%c R%c B%c D%c I%c Z%c C%c",
						p & 0x80 ? '+':'-',
						p & 0x40 ? '+':'-',
						p & 0x20 ? '+':'-',
						p & 0x10 ? '+':'-',
						p & 0x08 ? '+':'-',
						p & 0x04 ? '+':'-',
						p & 0x02 ? '+':'-',
						p & 0x01 ? '+':'-'
		);

		sprintf(register_info,
			"A:%02X  X:%02X  Y:%02X  P:%02X  S:%02X     Flags: %s",
			cpu->get_reg(M6502_A),
			cpu->get_reg(M6502_X),
			cpu->get_reg(M6502_Y),
			p,
			cpu->get_reg(M6502_S),
			flags
		);
	}
	printf("%s\n", register_info);
}

static void set_register(char *register_name, char *value) {
	static unsigned reg = 0;

	if (!strcmp(register_name, "pc")) {
		reg = M6502_PC;
	} else if (!strcmp(register_name, "a")) {
		reg = M6502_A;
	} else if (!strcmp(register_name, "x")) {
		reg = M6502_X;
	} else if (!strcmp(register_name, "y")) {
		reg = M6502_Y;
	}
	if (reg == 0) return;

	cpu->set_reg(reg, parse_hex(value));
}

static unsigned dump_memory(unsigned addr, unsigned lines) {
	for(int line=0; line < lines; line++) {
		printf("%04X|", addr);
		for(int i=0; i<16; i++) {
			printf("%02X", bus_read16(addr + i));
			if (((i+1) % 4) == 0) {
				printf("|");
			} else {
				printf(" ");
			}
		}
		for(int i=0; i<16; i++) {
			UINT8 c = bus_read16(addr + i);
			if (0x20 <= c && c <= 0x7F) {
				printf("%c", c);
			} else {
				printf(".");
			}

		}
		printf("\n");
		addr += 16;
	}
	return addr;
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

	char code[1000];
	sprintf(code, "%04X %s %s  %s", addr,
			monitor_is_breakpoint(addr) ? "*":" ",
			multi_byte, utils_str2upper(disasm));

	char source[1000] = "";
	if (source_labels[addr]) {
		strcat(source, source_labels[addr]);
		strcat(source, " ");
	}
	if (source_lines[addr]) {
		strcat(source, source_labels[addr] ? "":"      ");
		strcat(source, source_lines[addr]);
	}
	if (strlen(source)>0) {
		strcat(code, "                            ");
		code[32] = '|';
		strcpy(code+35, source);
	}



	printf("%s\n", code);
	return next_addr;
}

static unsigned disasm(unsigned addr, int lines) {
	for(int i=0; i<lines; i++) {
		addr = dump_code(addr);
	}
	return addr;
}

void monitor_breakpoint_set(unsigned addr) {
	if (breakpoints_count == MAX_BREAKPOINTS) return;
	// ignore if breakpoint exists
	for(int i=0; i<breakpoints_count; i++) {
		if (breakpoints[i] == addr) return;
	}
	// add breakpoint
	breakpoints[breakpoints_count++] = addr;
}

void monitor_breakpoint_del(unsigned index) {
	if (index >= breakpoints_count) return;

	// remove breakpoint
	for(int i = index; i<breakpoints_count-1; i++) {
		breakpoints[i] = breakpoints[i+1];
	}
	breakpoints_count--;
}

void breakpoints_list() {
	for(int i=0; i<breakpoints_count; i++) {
		printf("%02d: ", i);
		dump_code(breakpoints[i]);
	}
}

bool monitor_is_stop(unsigned addr) {
	return monitor_is_breakpoint(addr)
			|| is_step
			|| (is_stop_at_addr && addr == stop_at_addr)
			|| (is_stop_at_ret && cpu->is_ret_op(addr) && cpu->is_ret_frame());
}

bool monitor_is_breakpoint(unsigned addr) {
	for(int i=0; i<breakpoints_count; i++) {
		if (breakpoints[i] == addr) return TRUE;
	}

	return FALSE;
}

void monitor_help() {
	printf("\nCompy monitor\n\n");
	printf("Commands:\n");
	printf("r             Display Registers\n");
	printf("r reg value   Set Register [pc|a|x|y] with hex value\n");
	printf("d             Disassembly\n");
	printf("d addr        Disassembly from address\n");
	printf("da            Disassembly (again) from PC address\n");
	printf("m             Memory dump\n");
	printf("m addr        Memory dump from address\n");
	printf("s             Step one instruction\n");
	printf("t             Step over one instruction\n");
	printf("g             Run\n");
	printf("g r           Run until return of subroutine\n");
	printf("g addr        Run up to the specified address\n");
	printf("b             Display breakpoints\n");
	printf("b [set] addr  Set breakpoints at addr\n");
	printf("b del pos     Del breakpoint at position\n");
	printf("h             This help\n");
	printf("x             Exit emulator\n\n");
}

void monitor_enter() {
	if (!frontend_running()) return;
	is_step         = FALSE;
	is_enabled      = FALSE;
	is_stop_at_addr = FALSE;
	is_stop_at_ret  = FALSE;

	bool trace_was_enabled = trace_enabled;
	trace_enabled = FALSE;

	unsigned dasm_start = cpu->get_pc();
	unsigned mem_start  = 0;

	dump_registers();
	dump_code(cpu->get_pc());

	char buffer[MAX_LINE_SIZE+1];

	unsigned nparts = 0;
	bool in_loop = TRUE;
	while(in_loop && frontend_running()) {
		printf(">");
		fgets(buffer, MAX_LINE_SIZE, stdin);
		char *line = strdup(utils_trim(buffer));

		char **parts = utils_split(line, &nparts);

		if (nparts == 0 || !strcmp(parts[0],"r")) {
			if (nparts >= 3) {
				set_register(parts[1], parts[2]);
			}
			dump_registers();
			dump_code(cpu->get_pc());
			continue;
		} else if (!strcmp(parts[0], "d")) {
			if (nparts == 1) {
				dasm_start = disasm(dasm_start, 16);
			} else {
				unsigned addr = parse_hex(parts[1]);
				dasm_start = disasm(addr, 16);
			}
		} else if (!strcmp(parts[0], "m")) {
			if (nparts == 1) {
				mem_start = dump_memory(mem_start, 16);
			} else {
				unsigned addr = parse_hex(parts[1]);
				mem_start = dump_memory(addr, 16);
			}
		} else if (!strcmp(parts[0], "da")) {
			dasm_start = disasm(cpu->get_pc(), 16);
		} else if (!strcmp(parts[0], "g")) {
			in_loop = FALSE;
			if (nparts >1) {
				if (!strcmp(parts[1], "r")) {
					is_stop_at_ret = TRUE;
					cpu->set_ret_frame();
				} else {
					unsigned addr = parse_hex(parts[1]);
					stop_at_addr = addr;
					is_stop_at_addr = TRUE;
				}
			}
		} else if (!strcmp(parts[0], "b")) {
			if (nparts > 2) {
				unsigned addr = parse_hex(parts[2]);
				if (!strcmp(parts[1], "set")) {
					monitor_breakpoint_set(addr);
				} else if (!strcmp(parts[1], "del")) {
					monitor_breakpoint_del(addr);
				}
			} else if (nparts > 1) {
				unsigned addr = parse_hex(parts[1]);
				monitor_breakpoint_set(addr);
			}
			breakpoints_list();
		} else if (!strcmp(parts[0], "t")) {
			unsigned addr = disasm(cpu->get_pc(), 1);
			stop_at_addr = addr;
			is_stop_at_addr = TRUE;
			in_loop = FALSE;
		} else if (!strcmp(parts[0], "s")) {
			is_step = TRUE;
			in_loop = FALSE;
		} else if (!strcmp(parts[0], "h")) {
			monitor_help();
		} else if (!strcmp(parts[0], "x")) {
			in_loop = FALSE;
			frontend_shutdown();
		}
		free(line);
	}
	trace_enabled = trace_was_enabled;
}

/* source code handling */

void monitor_source_init() {
	memset(source_lines, 0, 0x10000 * sizeof(char *));
}

static inline void safe_substr(char *dst, char *src, size_t from, size_t n) {
	if (from<strlen(src)) {
		strncpy(dst, src + from, n);
		dst[n] = 0;
	} else {
		strcat(dst, "");
	}
}

static inline bool is_hex(char c) {
	return ('0' <= c && c <='9') || ('A' <= c && c <= 'F');
}

static inline bool is_hex_addr(char *s) {
	for(int i=0; i<4; i++) if (!is_hex(s[i])) return FALSE;
	return TRUE;
}

// look for not byte pattern after byte pattern
static char *get_source_line(char *line) {

	int i = 7;
	int state = 0;
	while (i<strlen(line)) {
		char c = line[i];
		bool is_hex_char = is_hex(c);
		bool is_space_char = c == ' ' || c == '\t';

		switch(state) {
		case 0:
			state = is_space_char ? 1 : 0;
			break;
		case 1:
			state = is_hex_char ? 2 : 0;
			break;
		case 2:
			state = is_hex_char ? 3 : 0;
			break;
		case 3:
			state = is_space_char ? 4 : 0;
			break;
		case 4:
			state = is_hex_char ? 2 : 5;
			break;
		}

		if (state == 5) return &line[i];
		i++;
	}
	return NULL;
}

// look for label pattern
static char *get_source_label_line(char *line) {

	int i = 7;
	int state = 0;
	unsigned start = 0;
	while (i<strlen(line)) {
		char c = line[i];
		bool is_space_char = c == ' ' || c == '\t';
		bool is_hex_char = is_hex(c);
		bool is_label_delimiter = c == ':';
		switch(state) {
		case 0:
			state = is_hex_char ? 1 : 0;
			break;
		case 1:
			state = is_hex_char ? 2 : 0;
			break;
		case 2:
			state = is_hex_char ? 3 : 0;
			break;
		case 3:
			state = is_hex_char ? 4 : 0;
			break;
		case 4:
			state = is_space_char ? 4 : 5;
			if (state == 5) start = i;
			break;
		case 5:
			state = is_space_char ? 6 : (is_label_delimiter ? 7 : 5);
			break;
		case 6:
			return NULL;
		}

		if (state == 7) return &line[start];
		i++;
	}
	return NULL;
}


static void monitor_source_read_line(char *line) {
	char buffer[2000];

	safe_substr(buffer, line, 0, 6);
	char *line_number = utils_trim(buffer);
	int n = atoi(line_number);
	if (n == 0) return;

	safe_substr(buffer, line, 7, 5);
	if (!strcmp(buffer, "FFFF>")) {
		safe_substr(buffer, line, 13, 4);
	} else if (is_hex_addr(buffer)) {
		safe_substr(buffer, line, 7, 4);
	} else {
		return;
	}

	int addr;
	sscanf(buffer, "%X", &addr);
	if (source_lines[addr]) {
		free(source_lines[addr]);
	}

	char *source_line = get_source_line(line);
	if (source_line!=NULL) {
		source_lines[addr] = strdup(utils_trim(source_line));
	}

	char *label_line = get_source_label_line(line);
	if (label_line!=NULL) {
		source_labels[addr] = strdup(utils_trim(label_line));
	}
}

void monitor_source_read_file(char *filename) {
	FILE *f = fopen(filename, "rt");
	if (!f) {
		fprintf(stderr, "cannot open file %s", filename);
		return;
	}

	char line[1000];
	while (fgets(line, 1000, f)) {
		monitor_source_read_line(line);
	}
	fclose(f);
}
