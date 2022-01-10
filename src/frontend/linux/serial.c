#include <SDL.h>
#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <errno.h>
#include "../../emu.h"

#define BUFFER_SIZE 1024

static char *fifo_path = "/tmp/semu_fifo";

static int fifo;

static UINT8 buffer[BUFFER_SIZE];

// let's assume there will never be more than INT_MAX data being transferred
static int buffer_pos_in = 0;
static int buffer_pos_out = 0;

static int running = 0;

static SDL_Thread *serial_thread;

static int is_fifo_alive() {
	return fifo >= 0;
}

static int receive_thread(void *ptr) {
	if (!is_fifo_alive()) return 0;

	UINT8 c;
	while(running) {
		read(fifo, &c, 1);
		buffer[buffer_pos_in++] = c;
	}
	return 0;
}

int semu_open() {
	mkfifo(fifo_path, 0666);

	fifo = open(fifo_path, O_SYNC);
	if (fifo < 0) {
		fprintf(stderr, "Error opening fifo: %s - %s\n", fifo_path, strerror(errno));
		return 0;
	}

	running = 1;
	serial_thread = SDL_CreateThread(receive_thread, "SerialThread", (void *)NULL);
	return 1;
}

void semu_close() {
	running = 0;
	if (!is_fifo_alive()) return;

	close(fifo);
}

int semu_has_data() {
	return buffer_pos_in != buffer_pos_out && is_fifo_alive() ;
}

UINT8 semu_receive() {
	if (semu_has_data()) {
		UINT8 c = buffer[buffer_pos_out % BUFFER_SIZE];
		buffer_pos_out++;
		return c;
	}

	// it should never be called if there is no data
	return 0;
}

void semu_send(UINT8 data) {
	if (!is_fifo_alive()) return;
	write(fifo, &data, 1);
}
