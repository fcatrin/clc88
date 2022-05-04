#ifndef _WOPI_H
#define _WOPI_H

void wopi_sound_init(UINT16 freq);
void wopi_write(UINT16 reg, UINT8 val);
void wopi_process(INT16 *buffer, UINT16 size);


#endif
