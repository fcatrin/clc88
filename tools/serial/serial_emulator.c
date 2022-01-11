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
int running;

int semu_open() {
	mkfifo(fifo_path, 0600);
	fifo = open(fifo_path, O_NONBLOCK | O_RDWR | O_SYNC);
	if (fifo < 0) {
		fprintf(stderr, "Error opening fifo: %s - %s\n", fifo_path, strerror(errno));
		return 0;
	}
	running = 1;
	return 1;
}

void semu_close() {
	running = 0;
	close(fifo);
}

int semu_receive(uint8_t* buffer, uint16_t size) {
	printf("wait for %d bytes\n", size);
	while(running) {
		int n = read(fifo, buffer, size);
		if (n <= 0) {
			printf("wait\n");
			usleep(1000000);
		} else {
			printf("received %d bytes\n", n);
			return n;
		}
	}
	printf("closing receive channel\n");
	return 0;
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
