#include <stdio.h>
#include "emu.h"
#include "sound/claudio.h"

/*
 * Consider that the sound registers can be changed X times per frame
 * 5 times per frame allows to use a stable buffer using 44100 sampling rate
 *
 * 44100 / 60 frames -> 735 samples per frame -> 147 samples per 1/5 frames
 */

#define CLAUDIO_BUFFER_SIZE 44100
#define SOUND_BUFFER_SIZE (CLAUDIO_BUFFER_SIZE*20)

INT16 claudio_buffer[CLAUDIO_BUFFER_SIZE];
INT16 sound_buffer_0[SOUND_BUFFER_SIZE];
INT16 sound_buffer_1[SOUND_BUFFER_SIZE];

INT16 *sound_buffers[] = {sound_buffer_0, sound_buffer_1};
unsigned buffer_write_index[2];

unsigned active_sound_buffer = 0;

float samples_to_process;

void sound_init() {
	claudio_sound_init(44100);
	samples_to_process = 0;
}

void sound_register_write(UINT16 addr, UINT8 val) {
	unsigned reg  = addr & 0x0F;
	claudio_write(reg, val);
}

static bool updating_buffer = FALSE;
void sound_process(float samples) {
	samples_to_process += samples * 2;
	if (samples_to_process < CLAUDIO_BUFFER_SIZE) return;

	samples_to_process -= CLAUDIO_BUFFER_SIZE;

	while (updating_buffer);

	claudio_process (claudio_buffer, CLAUDIO_BUFFER_SIZE);

	INT16 *sound_buffer = sound_buffers[active_sound_buffer];
	unsigned claudio_write_index = buffer_write_index[active_sound_buffer];
	for(unsigned i=0; i<CLAUDIO_BUFFER_SIZE && claudio_write_index < SOUND_BUFFER_SIZE; i+=2) {
		INT16 claudio_l = claudio_buffer[i+0];
		INT16 claudio_r = claudio_buffer[i+1];

		sound_buffer[claudio_write_index++] = claudio_l;
		sound_buffer[claudio_write_index++] = claudio_r;
	}

	buffer_write_index[active_sound_buffer] = claudio_write_index;
}

void sound_fill_buffer(INT16 **buffer, unsigned *size) {
	updating_buffer = TRUE;
	int current_sound_buffer = active_sound_buffer;
	active_sound_buffer = 1 - active_sound_buffer;

	*buffer = sound_buffers[current_sound_buffer];
	*size   = buffer_write_index[current_sound_buffer];

	buffer_write_index[current_sound_buffer] = 0;
	updating_buffer = FALSE;
}

void sound_done() {
}
