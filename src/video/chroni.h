#ifndef _CHRONI_H
#define _CHRONI_H

void  chroni_register_write(UINT8 index, UINT8 value);

UINT8 chroni_register_read(UINT8 index);
UINT8 chroni_vram_read_linear(UINT32 index); // used by monitor

void  chroni_init();
void  chroni_frame_start();
void  chroni_frame_end();
void  chroni_frame_start();
bool  chroni_frame_is_complete();

void  chroni_scanline_back_porch();
void  chroni_scanline_front_porch();
void  chroni_scanline_display();

#endif
