#ifndef _SOUND_H
#define _SOUND_H

void sound_init();
void sound_process(float samples);
void sound_done();

void sound_register_write(UINT16 addr, UINT8 val);
void sound_fill_buffer(UINT16 **buffer, unsigned *size);

INT16 *sound_get_monitor_buffer(unsigned size);

#endif
