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
	int blocks = (size+block_size-1) / block_size;

	printf("upload %s size:%ld block_size:%d blocks:%d\n", filename, size, block_size, blocks);

	int block_number = 1;
	do {
		int n = fread(buffer+1, 1, block_size, f);
		buffer[0] = size > block_size ? 0x00 : 0x01;
		buffer[BUFFER_SIZE-1] = n;

		printf("send block %d size:%d eof:%s\n", block_number, n, (buffer[0] ? "true":"false"));

		upload_buffer();
		block_number++;

		size -= block_size;
	} while (size > 0);

	printf("upload complete\n");

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
	printf("wait for destination ready\n");
	serial_interface->receive(buffer, 1);

	printf("send block\n");
	serial_interface->send(buffer, BUFFER_SIZE);
}

int main(int argc, char *argv[]) {
	if (argc != 2) {
		printf("usage %s file.xex\n", argv[0]);
		return 0;
	}

	char *xex_filename = argv[1];

	serial_interface = &serial_emu;

	printf("open serial interface\n");
	if (serial_interface->open()) {
		upload(xex_filename);
		printf("close serial interface\n");
		serial_interface->close();
	}
	printf("done\n");
}
