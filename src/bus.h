#ifndef _BUS_H
#define _BUS_H

#define CHRONI_START  0x9000
#define CHRONI_END    0x907F

#define STORAGE_START 0x9080
#define STORAGE_END   0x9087

#define KEYB_START    0x9090
#define KEYB_END      0x909F

#define SOUND_POKEY_START 0x9100
#define SOUND_POKEY_END   0x911F

#define CHRONI_MEM_START 0xA000
#define CHRONI_MEM_END   0xDFFF

UINT8 bus_read16(UINT16 addr);
void  bus_write16(UINT16 addr, UINT8 value);
void  bus_write(UINT16 addr, UINT8 *values, UINT16 size);

#endif
