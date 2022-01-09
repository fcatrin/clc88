#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>
#include <serial_interface.h>
#include <serial_emulator.h>

#define BUFFER_SIZE 0x100
uint8_t buffer[BUFFER_SIZE];

struct serial_interface *serial_interface;

static void upload(const char *filename) {
	FILE *f = fopen(filename, "rb");
	if (!f) {
		fprintf(stderr, "Error opening %s: %s\n", filename, strerror(errno));
		return;
	}


	long size = file_size();
	int block_size = BUFFER_SIZE-2;

	do {
		int n = fread(buffer+2, block_size, 1, f);
		buffer[0] = size > block_size ? 0xff : 0xfe;
		buffer[1] = n;

		upload_buffer();

		size -= block_size;
	} while (size > 0);

	fclose(f);
}

static long file_size(FILE *f) {
	fseek(f, 0L, SEEK_END);
	long size = ftell(f);
	fseek(f, 0L, SEEK_SET);
	return size;
}

static void wait_for_request() {
	serial_interface->receive(1);
}

static void upload_buffer() {
	wait_for_request();

	for(int i=0; i<BUFFER_SIZE; i++) {
		serial_interface->send(buffer[i]);
	}
}

int main(int argc, char *argv[]) {

	serial_interface = serial_emu;

	serial_interface->open();
	upload('/home/fcatrin/tmp/testbin.xex');
	serial_interface->close();

}
