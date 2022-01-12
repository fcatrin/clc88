#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <errno.h>
#include "serial_interface.h"

#define LOGTAG "SERIAL"
#ifdef TRACE_SERIAL
#define TRACE
#endif
#include "trace.h"

static char *fifo_path  = "/tmp/semu_fifo";

int fifo;
int running;

int semu_open() {
	mkfifo(fifo_path, 0600);
	fifo = open(fifo_path, O_RDWR | O_NONBLOCK);
	if (fifo < 0) {
		LOGE(LOGTAG, "Error opening fifo: %s - %s", fifo_path, strerror(errno));
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
	LOGV(LOGTAG, "wait for %d bytes", size);
	while(running) {
		int n = read(fifo, buffer, size);
		if (n < 0) {
			if (errno != EAGAIN) LOGE(LOGTAG, "cannot read %s", strerror(errno));
		} else if (n == 0) {
			usleep(100);
		} else {
			LOGV(LOGTAG, "received %d bytes", n);
			return n;
		}
	}
	LOGV(LOGTAG, "closing receive channel");
	return 0;
}

static void wait_for_other_end() {
	int n;
	do {
		int err = ioctl(fifo, FIONREAD, &n);
		if (err < 0) {
			LOGE(LOGTAG, "ioctl failed %s", strerror(errno));
		}
		usleep(100);
	} while (n != 0);
}

void hex_dump(uint8_t *buffer, uint16_t size) {
	char text[3*65536];
	sprintf(text, "data[%d]: ", size);
	for(int i=0; i<size; i++) {
		char hexbuf[200];
		sprintf(hexbuf, "%02X ", buffer[i]);
		strcat(text, hexbuf);
	}
	LOGV(LOGTAG, text);
}

void semu_send(uint8_t *buffer, uint16_t size) {
	LOGV(LOGTAG, "send %d bytes", size);

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
