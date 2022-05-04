#include <stdio.h>
#include "emu.h"
#include "sound/wopi.h"

#define WOPI_BUFFER_SIZE 735*2
#define SOUND_BUFFER_SIZE (WOPI_BUFFER_SIZE*20)

INT16 wopi_buffer[WOPI_BUFFER_SIZE];
INT16 sound_buffer_0[SOUND_BUFFER_SIZE];
INT16 sound_buffer_1[SOUND_BUFFER_SIZE];

INT16 *sound_buffers[] = {sound_buffer_0, sound_buffer_1};
bool sound_buffer_full[] = {0, 0};

unsigned buffer_write_index[2];
unsigned active_sound_buffer = 0;

float samples_to_process;

void sound_init() {
	wopi_sound_init(44100);
	samples_to_process = 0;
}

void sound_register_write(UINT16 addr, UINT8 val) {
	unsigned reg  = addr & 0x0F;
	wopi_write(reg, val);
}

void sound_process(float samples) {
	samples_to_process += samples * 2;
	if (samples_to_process < WOPI_BUFFER_SIZE) return;

	samples_to_process -= WOPI_BUFFER_SIZE;

	while (sound_buffer_full[active_sound_buffer]);

	wopi_process(wopi_buffer, WOPI_BUFFER_SIZE);

	INT16 *sound_buffer = sound_buffers[active_sound_buffer];
	unsigned wopi_write_index = buffer_write_index[active_sound_buffer];
	for(unsigned i=0; i<WOPI_BUFFER_SIZE && wopi_write_index < SOUND_BUFFER_SIZE; i+=2) {
		INT16 wopi_l = wopi_buffer[i+0];
		INT16 wopi_r = wopi_buffer[i+1];

		sound_buffer[wopi_write_index++] = wopi_l;
		sound_buffer[wopi_write_index++] = wopi_r;
	}

	buffer_write_index[active_sound_buffer] = wopi_write_index;
	sound_buffer_full[active_sound_buffer] = wopi_write_index >= SOUND_BUFFER_SIZE;
}

void sound_fill_buffer(INT16 **buffer, unsigned *size) {
    if (!sound_buffer_full[active_sound_buffer]) return;

	int current_sound_buffer = active_sound_buffer;

	*buffer = sound_buffers[current_sound_buffer];
	*size   = buffer_write_index[current_sound_buffer];

    int second_buffer = 1 - active_sound_buffer;
    buffer_write_index[second_buffer] = 0;
	sound_buffer_full[second_buffer] = FALSE;
	active_sound_buffer = second_buffer;
}

void sound_done() {
}
