#ifndef _CHRONI_H
#define _CHRONI_H

#define CHRONI_START 0x9000
#define CHRONI_END   0x907F

#define CHRONI_MEM_START 0xA000
#define CHRONI_MEM_END   0xDFFF

void  chroni_register_write(UINT8 index, UINT8 value);
void  chroni_vram_write(UINT16 index, UINT8 value);

UINT8 chroni_register_read(UINT8 index);
UINT8 chroni_vram_read(UINT16 index);

void  chroni_run();


#endif
