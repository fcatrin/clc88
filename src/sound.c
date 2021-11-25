#include <stdio.h>
#include "emu.h"
#include "sound/pokey/pokey.h"

/*
 * Consider that the sound registers can be changed X times per frame
 * 5 times per frame allows to use a stable buffer using 44100 sampling rate
 *
 * 44100 / 60 frames -> 735 samples per frame -> 147 samples per 1/5 frames
 */

#define POKEY_BUFFER_SIZE 147*2
#define SOUND_BUFFER_SIZE (POKEY_BUFFER_SIZE*20)

#define POKEY_CHIPS 2

UINT8 pokey_buffer_0[POKEY_BUFFER_SIZE];
UINT8 pokey_buffer_1[POKEY_BUFFER_SIZE];
INT16 sound_buffer_0[SOUND_BUFFER_SIZE];
INT16 sound_buffer_1[SOUND_BUFFER_SIZE];

INT16 *sound_buffers[] = {sound_buffer_0, sound_buffer_1};
unsigned buffer_write_index[2];

unsigned active_sound_buffer = 0;

float samples_to_process;

void sound_init() {
	pokey_sound_init(FREQ_17_APPROX, 44100, POKEY_CHIPS);
	samples_to_process = 0;
}

void sound_register_write(uint16 addr, uint8 val) {
	unsigned chip = (addr & 0x10) ? 1 : 0;
	unsigned reg  = addr & 0x0F;
	pokey_update_sound(reg, val, chip, 64);
}

static bool updating_buffer = FALSE;
void sound_process(float samples) {
	samples_to_process += samples * 2;
	if (samples_to_process < POKEY_BUFFER_SIZE) return;

	samples_to_process -= POKEY_BUFFER_SIZE;

	while (updating_buffer);

	pokey_process (pokey_buffer_0, POKEY_BUFFER_SIZE, 0);
	pokey_process (pokey_buffer_1, POKEY_BUFFER_SIZE, 1);

	INT16 *sound_buffer = sound_buffers[active_sound_buffer];
	unsigned pokey_write_index = buffer_write_index[active_sound_buffer];
	for(unsigned i=0; i<POKEY_BUFFER_SIZE && pokey_write_index < SOUND_BUFFER_SIZE; i+=2) {
		int16 pokey0_l = pokey_buffer_0[i+0] - 128;
		int16 pokey0_r = pokey_buffer_0[i+1] - 128;
		int16 pokey1_l = pokey_buffer_1[i+0] - 128;
		int16 pokey1_r = pokey_buffer_1[i+1] - 128;

		sound_buffer[pokey_write_index++] = pokey0_l * 256 + pokey1_l * 256;
		sound_buffer[pokey_write_index++] = pokey0_r * 256 + pokey1_r * 256;
	}

	buffer_write_index[active_sound_buffer] = pokey_write_index;
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
