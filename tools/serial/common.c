#include <stdio.h>
#include <string.h>
#include "common.h"

static char hex_text[3*65536];

char *hex_dump(uint8_t *buffer, uint16_t size) {
	sprintf(hex_text, "data[%d]: ", size);
	for(int i=0; i<size; i++) {
		char hexbuf[200];
		sprintf(hexbuf, "%02X ", buffer[i]);
		strcat(hex_text, hexbuf);
	}
	return hex_text;
}
