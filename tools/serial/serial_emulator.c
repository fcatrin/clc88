#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <errno.h>
#include "serial_interface.h"

static char *fifo_path  = "/tmp/semu_fifo";

int fifo;
int running;

int semu_open() {
	mkfifo(fifo_path, 0600);
	fifo = open(fifo_path, O_RDWR | O_NONBLOCK);
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
	printf("wait for %d bytes on fifo %d\n", size, fifo);
	while(running) {
		int n = read(fifo, buffer, size);
		if (n <= 0) {
			//perror("wait");
			printf(".");
			fflush(stdout);
			usleep(10000);
		} else {
			printf("\nreceived %d bytes\n", n);
			return n;
		}
	}
	printf("closing receive channel\n");
	return 0;
}

static void wait_for_other_end() {
	int n;
	do {
		int err = ioctl(fifo, FIONREAD, &n);
		if (err < 0) {
			perror("ioctl failed");
		}
		usleep(1000);
	} while (n != 0);
}

void hex_dump(uint8_t *buffer, uint16_t size) {
	printf("data[%d]: ", size);
	for(int i=0; i<size; i++) {
		printf("%02X ", buffer[i]);
	}
	printf("\n");
}

void semu_send(uint8_t *buffer, uint16_t size) {
	printf("send %d bytes on fifo %d\n", size, fifo);

	hex_dump(buffer, size);
	write(fifo, buffer, size);
	wait_for_other_end();
}

struct serial_interface serial_emu = {
	semu_open,
	semu_close,
	semu_receive,
	semu_send
};
