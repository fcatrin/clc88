#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <errno.h>
#include "common.h"
#include "serial_interface.h"

#define LOGTAG "TTY"
#ifdef TRACE_TTY
#define TRACE
#endif
#include "trace.h"

static char *tty_path  = "/dev/ttyUSB0";

int tty;
int running;

char* tty_get_name() {
	return "tty";
}

int tty_open() {
	tty = open(tty_path, O_RDWR | O_NONBLOCK);
	if (tty < 0) {
		LOGE(LOGTAG, "Error opening tty: %s - %s", tty_path, strerror(errno));
		return 0;
	}
	running = 1;
	return 1;
}

void tty_close() {
	running = 0;
	close(tty);
}

int tty_receive(uint8_t* buffer, uint16_t size) {
	LOGV(LOGTAG, "wait for %d bytes", size);
	while(running) {
		int n = read(tty, buffer, size);
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
		int err = ioctl(tty, FIONREAD, &n);
		if (err < 0) {
			LOGE(LOGTAG, "ioctl failed %s", strerror(errno));
		}
		usleep(100);
	} while (n != 0);
}

void tty_send(uint8_t *buffer, uint16_t size) {
	LOGV(LOGTAG, "send %d bytes", size);

	LOGV(LOGTAG, "%s", hex_dump(buffer, size));
	write(tty, buffer, size);
	wait_for_other_end();
}

struct serial_interface serial_tty = {
	tty_open,
	tty_close,
	tty_receive,
	tty_send,
	tty_get_name
};
