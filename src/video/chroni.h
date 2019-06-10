#ifndef _CHRONI_H
#define _CHRONI_H

void  chroni_register_write(UINT8 index, UINT8 value);
void  chroni_vram_write(UINT16 index, UINT8 value);

UINT8 chroni_register_read(UINT8 index);
UINT8 chroni_vram_read(UINT16 index);

void  chroni_init();
void  chroni_run_frame();


#endif
