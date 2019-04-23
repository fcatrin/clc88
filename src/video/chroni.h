#ifndef _CHRONI_H
#define _CHRONI_H

#define CHRONI_START 0xD000
#define CHRONI_END   0xD07F

#define CHRONI_MEM_START 0xA000
#define CHRONI_MEM_END   0xBFFF

void  chroni_register_write(UINT8 index, UINT8 value);
void  chroni_vram_write(UINT16 index, UINT8 value);
UINT8 chroni_vram_read(UINT16 index);

void  chroni_run();


#endif
