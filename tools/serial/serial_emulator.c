#include "serial_interface.h"

void semu_open() {

}
void semu_close() {

}

uint8_t semu_receive(uint16_t size) {
	return 0;
}

void semu_send(uint8_t data) {

}

struct serial_interface serial_emu = {
	semu_open,
	semu_close,
	semu_receive,
	semu_send
};
