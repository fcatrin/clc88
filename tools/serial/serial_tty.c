#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <termios.h>
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

static int set_interface_attribs (int fd, int speed, int parity);

char* tty_get_name() {
	return "tty";
}

int tty_open() {
	tty = open(tty_path, O_RDWR | O_NOCTTY | O_NONBLOCK);
	if (tty < 0) {
		LOGE(LOGTAG, "Error opening tty: %s - %s", tty_path, strerror(errno));
		return 0;
	}
	set_interface_attribs(tty, 9600, 0); // 9600 8n1
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
		if (n > 0) {
			LOGV(LOGTAG, "received %d bytes", n);
			return n;
		}

		if (n < 0 && errno != EAGAIN) LOGE(LOGTAG, "cannot read %s", strerror(errno));
		usleep(100);
	}
	LOGV(LOGTAG, "closing receive channel");
	return 0;
}

static void wait_for_other_end() {
	int n;
	do {
		LOGV(LOGTAG, "wait_for_other_end");
		int err = ioctl(tty, FIONREAD, &n);
		if (err < 0) {
			LOGE(LOGTAG, "ioctl failed %s", strerror(errno));
		}
		if (n!=0) {
			if (n > 0) LOGV(LOGTAG, "There are still %d bytes on the input", n);
			usleep(1000000);
		}
	} while (n != 0);
}

void tty_send(uint8_t *buffer, uint16_t size) {
	LOGV(LOGTAG, "send %d bytes", size);

	LOGV(LOGTAG, "%s", hex_dump(buffer, size));
	write(tty, buffer, size);
	LOGV(LOGTAG, "sent %d bytes", size);
	wait_for_other_end();
}

// serial setup routine from https://gist.github.com/wdalmut/7480422
int set_interface_attribs (int fd, int speed, int parity) {
	struct termios tty;
	memset (&tty, 0, sizeof tty);
	if (tcgetattr (fd, &tty) != 0) {
		printf ("error %d from tcgetattr", errno);
		return -1;
	}

	cfsetospeed (&tty, speed);
	cfsetispeed (&tty, speed);

	tty.c_cflag = (tty.c_cflag & ~CSIZE) | CS8;     // 8-bit chars
	// disable IGNBRK for mismatched speed tests; otherwise receive break
	// as \000 chars
	tty.c_iflag &= ~IGNBRK;         // ignore break signal
	tty.c_lflag = 0;                // no signaling chars, no echo,
									// no canonical processing
	tty.c_oflag = 0;                // no remapping, no delays
	tty.c_cc[VMIN]  = 0;            // read doesn't block
	tty.c_cc[VTIME] = 5;            // 0.5 seconds read timeout

	tty.c_iflag &= ~(IXON | IXOFF | IXANY); // shut off xon/xoff ctrl

	tty.c_cflag |= (CLOCAL | CREAD);// ignore modem controls,
									// enable reading
	tty.c_cflag &= ~(PARENB | PARODD);      // shut off parity
	tty.c_cflag |= parity;
	tty.c_cflag &= ~CSTOPB;
	tty.c_cflag &= ~CRTSCTS;

	if (tcsetattr (fd, TCSANOW, &tty) != 0)	{
		printf("error %d from tcsetattr\n", errno);
		return -1;
	}
	return 0;
}

struct serial_interface serial_tty = {
	tty_open,
	tty_close,
	tty_receive,
	tty_send,
	tty_get_name
};
