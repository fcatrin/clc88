#ifndef _CVPU_H
#define _CVPU_H

#define CVPU_START 0xD000
#define CVPU_END   0xD07F

#define CVPU_MEM_START 0xA000
#define CVPU_MEM_END   0xBFFF

void cvpu_register_write(UINT8 index, UINT8 value);
void cvpu_vram_write(UINT16 index, UINT8 value);
UINT8 cvpu_vram_read(UINT16 index);

void cvpu_run();


#endif
