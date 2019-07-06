#ifndef _KEYBOARD_H
#define _KEYBOARD_H

void keyb_init();
void keyb_done();

void keyb_update(int keycode, bool down);
UINT8 keyb_get_reg(int reg);

#endif
