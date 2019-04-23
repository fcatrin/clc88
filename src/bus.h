#ifndef _BUS_H
#define _BUS_H

UINT8 bus_read16(UINT16 addr);
void  bus_write16(UINT16 addr, UINT8 value);
void  bus_write(UINT16 addr, UINT8 *values, UINT16 size);

#endif
