#ifndef __SERIAL_INTERFACE
#define __SERIAL_INTERFACE

#include <ctype.h>

struct {
	void    (*open)();
	void    (*close)();
	uint8_t (*receive)(uint16_t size);
	void    (*send)(uint8_t data);
} serial_interface;


#endif
