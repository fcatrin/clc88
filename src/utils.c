#include <stdio.h>
#include <string.h>
#include <errno.h>
#include "emu.h"
#include "bus.h"
#include "trace.h"

void utils_load_xex(char *filename) {
	UINT8 buffer[0x1000];

	FILE *f = fopen(filename, "rb");
	if (!f) {
		LOGE("Error opening %s: %s", filename, strerror(errno));
		return;
	}

	int n=0;
	while((n = fread(buffer, 2, 1, f))) {
		if (buffer[0] & (buffer[1] == 0xFF)) {
			LOGV("skipping header");
			continue;
		}
		UINT16 offset = buffer[0] + (buffer[1] << 8);
		fread(buffer, 2, 1, f);
		UINT16 size = buffer[0] + (buffer[1] << 8) - offset + 1;
		LOGV("reading offset %04X size: %04X", offset, size);
		fread(buffer, size, 1, f);

		bus_write(offset, buffer, size);
	}

	fclose(f);
}

void utils_dump_mem(UINT16 offset, UINT16 size) {
	UINT16 address = offset & 0xFFF0;
	UINT16 end = offset + size;

	do {
		printf("%04X: ", address);
		for(int i=0; i<16; i++) {
			printf("%02X ", bus_read16(address + i));
		}
		printf("\n");
		address+=16;
	} while(address < end && address != 0x0000);

}
