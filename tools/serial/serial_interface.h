#ifndef __SERIAL_INTERFACE
#define __SERIAL_INTERFACE

#include <stdint.h>

struct serial_interface {
	int     (*open)    ();
	void    (*close)   ();
	int     (*receive) (uint8_t *buffer, uint16_t size);
	void    (*send)    (uint8_t* buffer, uint16_t size);
};

#endif
