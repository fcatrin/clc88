#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>
#include <serial_interface.h>
#include <serial_emulator.h>

#define BUFFER_SIZE 0x0fe
uint8_t buffer[BUFFER_SIZE];

struct serial_interface *serial_interface;

static long file_size(FILE *f);
static void upload_buffer();

static void upload(const char *filename) {
	FILE *f = fopen(filename, "rb");
	if (!f) {
		fprintf(stderr, "Error opening %s: %s\n", filename, strerror(errno));
		return;
	}


	long size = file_size(f);
	int block_size = BUFFER_SIZE-2;

	do {
		int n = fread(buffer+1, block_size, 1, f);
		buffer[0] = size > block_size ? 0x00 : 0x01;
		buffer[BUFFER_SIZE-1] = n;

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

static void upload_buffer() {
	// wait for request
	serial_interface->receive(buffer, 1);

	serial_interface->send(buffer, BUFFER_SIZE);
}

int main(int argc, char *argv[]) {

	serial_interface = &serial_emu;

	if (serial_interface->open()) {
		upload("/home/fcatrin/tmp/testbin.xex");
		serial_interface->close();
	}

}
