#include "sound/pokey/pokey.h"

/*
 * Consider that the sound registers can be changed X times per frame
 * 5 times per frame allows to use a stable buffer using 44100 sampling rate
 *
 * 44100 / 60 frames -> 735 samples per frame -> 147 samples per 1/5 frames
 */

#define BUFFER_SIZE 147

unsigned char sound_buffer[BUFFER_SIZE];

void sound_init() {
	pokey_sound_init(FREQ_17_APPROX, 44100, 1);
}

void sound_process() {
	pokey_process (sound_buffer, BUFFER_SIZE);
}

void sound_register_write(uint16 addr, uint8 val) {
	pokey_update_sound(addr, val, 1, 64);
}

void sound_done() {

}
