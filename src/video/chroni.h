#ifndef _CHRONI_H
#define _CHRONI_H

#define STATUS_VBLANK         0x80
#define STATUS_HBLANK         0x40
#define STATUS_IS_EMULATOR    0x20
#define STATUS_ENABLE_CHRONI  0x10
#define STATUS_ENABLE_SPRITES 0x08
#define STATUS_ENABLE_INTS    0x04

void  chroni_register_write(UINT8 index, UINT8 value);

UINT8  chroni_register_read(UINT8 index);
UINT16 chroni_vram_read(UINT16 addr); // used by monitor
UINT16 *chroni_registers_read();      // used by monitor

void  chroni_init();
void  chroni_frame_start();
void  chroni_frame_end();
void  chroni_frame_start();
bool  chroni_frame_is_complete();

void  chroni_scanline_back_porch();
void  chroni_scanline_front_porch();
void  chroni_scanline_display();

#endif
