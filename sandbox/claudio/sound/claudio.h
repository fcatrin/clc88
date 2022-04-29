#ifndef _CLAUDIO_H
#define _CLAUDIO_H

void claudio_sound_init(UINT16 freq);
void claudio_write(UINT16 reg, UINT8 val);
void claudio_process(INT16 *buffer, UINT16 size);


#endif
