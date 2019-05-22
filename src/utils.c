#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include <errno.h>
#include "emu.h"
#include "bus.h"
#include "trace.h"

#define LOGTAG "UTILS"

void utils_load_xex(char *filename) {
	UINT8 buffer[0x1000];

	FILE *f = fopen(filename, "rb");
	if (!f) {
		LOGE(LOGTAG, "Error opening %s: %s", filename, strerror(errno));
		return;
	}

	int n=0;
	while((n = fread(buffer, 2, 1, f))) {
		if (buffer[0] & (buffer[1] == 0xFF)) {
			LOGV(LOGTAG, "skipping header");
			continue;
		}
		UINT16 offset = buffer[0] + (buffer[1] << 8);
		fread(buffer, 2, 1, f);
		UINT16 size = buffer[0] + (buffer[1] << 8) - offset + 1;
		LOGV(LOGTAG, "reading offset %04X size: %04X", offset, size);
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

char *utils_str2lower(const char *src) {
	static char buffer[127+1];
	char *dst = buffer;
	while( *src )
		*dst++ = tolower(*src++);
	*dst = '\0';
	return buffer;
}

char *utils_str2upper( const char *src) {
	static char buffer[127+1];
	char *dst = buffer;
	while( *src )
		*dst++ = toupper(*src++);
	*dst = '\0';
	return buffer;
}
