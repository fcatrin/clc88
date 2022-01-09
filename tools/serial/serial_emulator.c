#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <errno.h>
#include "serial_interface.h"

static char *fifo_path = "/tmp/semu_fifo";

int fifo;

int semu_open() {
	fifo = open(fifo_path, O_SYNC);
	if (fifo < 0) {
		fprintf(stderr, "Error opening fifo: %s - %s\n", fifo_path, strerror(errno));
		return 0;
	}
	return 1;
}

void semu_close() {
	close(fifo);
}

int semu_receive(uint8_t* buffer, uint16_t size) {
	return read(fifo, buffer, size);
}

void semu_send(uint8_t *buffer, uint16_t size) {
	write(fifo, buffer, size);
}

struct serial_interface serial_emu = {
	semu_open,
	semu_close,
	semu_receive,
	semu_send
};
