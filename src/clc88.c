#include "cpu.h"

int main(int argc, char *argv[]) {
	v_cpu cpu = cpu_init(CPU_Z80);
	cpu.reset();

	return 0;
}
