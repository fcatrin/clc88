#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include "emu.h"
#include "bus.h"

#define LOGTAG "UTILS"
#ifdef TRACE_UTILS
#define TRACE
#endif
#include "trace.h"
#include "utils.h"

#define MAX_MEM 0x10000

void utils_load_xex(char *filename) {
	UINT8 buffer[MAX_MEM];

	FILE *f = fopen(filename, "rb");
	if (!f) {
		LOGE(LOGTAG, "Error opening %s: %s", filename, strerror(errno));
		return;
	}

	while (fread(buffer, 2, 1, f)) {
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

void utils_load_bin(char *filename, UINT16 addr) {
	UINT8 buffer[MAX_MEM];

	FILE *f = fopen(filename, "rb");
	if (!f) {
		LOGE(LOGTAG, "Error opening %s: %s", filename, strerror(errno));
		return;
	}

	// read as much as possible without surpassing buffer size
	int n = fread(buffer, 1, MAX_MEM, f);

	// restrict size to available space
	if (addr + n > MAX_MEM) n = MAX_MEM - addr;

	bus_write(addr, buffer, n);

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

bool utils_starts_with(const char *s, const char *prefix) {
	if (strlen(s) < strlen(prefix)) return FALSE;

	for(int i=0; i<strlen(prefix); i++) {
		if (s[i] != prefix[i]) return FALSE;
	}
	return TRUE;
}

static inline bool is_empty_char(char c) {
	return c == '\t' || c == ' ' || c=='\n' || c=='\r';
}

char *utils_ltrim(const char *s) {
	static char buffer[1024];
	if (s == NULL) return NULL;

	int i = 0;
	int d = 0;

	while(is_empty_char(s[i])) i++;
	while(s[i]) buffer[d++] = s[i++];
	buffer[d] = 0;

	return buffer;
}

char *utils_rtrim(const char *s) {
	static char buffer[1024];
	if (s == NULL) return NULL;

	int pos = strlen(s)-1;
	while (pos>=0 && is_empty_char(s[pos])) pos--;

	pos++;
	for(int i=0; i<pos; i++) {
		buffer[i] = s[i];
	}
	buffer[pos] = 0;
	return buffer;
}

char *utils_trim(const char *s) {
	return utils_rtrim(utils_ltrim(s));
}

char **utils_split(const char *s, unsigned *count) {
	static char *parts[100];
	if (s == NULL) {
		*count = 0;
		return NULL;
	}

	char *part;
	char *str = (char *)s;
	int i = 0;
	while ((part = strtok(str, " "))) {
		parts[i++] = part;
		str = NULL;
	}
	*count = i;
	return parts;
}

char *utils_format_date(time_t time) {
	static char buffer[100];

	int len = sizeof(buffer);
	struct tm t;

	tzset();
	if (localtime_r(&(time), &t) != NULL) {
		if (strftime(buffer, len, "%Y%m%d", &t)) {
			return strdup(buffer);
		}
	}
	return strdup("000000");

}

char *utils_format_time(time_t time) {
	static char buffer[100];

	int len = sizeof(buffer);
	struct tm t;

	tzset();
	if (localtime_r(&(time), &t) != NULL) {
		if (strftime(buffer, len, "%H%M%S", &t)) {
			return strdup(buffer);
		}
	}
	return strdup("000000");
}
