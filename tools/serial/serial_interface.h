#ifndef __SERIAL_INTERFACE
#define __SERIAL_INTERFACE

#include <stdint.h>

struct serial_interface {
	void    (*open)();
	void    (*close)();
	uint8_t (*receive)(uint16_t size);
	void    (*send)(uint8_t data);
};

#endif
