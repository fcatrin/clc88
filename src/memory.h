#ifndef _MEMORY_H
#define _MEMORY_H

UINT8 mem_readmem16(UINT16 addr);
void  mem_writemem16(UINT16 addr, UINT8 value);
void  mem_write(UINT16 addr, UINT8 *values, UINT16 size);

#endif
