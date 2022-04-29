#include <stdio.h>
#include <math.h>
#include "emu.h"
#include "claudio.h"

#define SIN_SIZE 1024

typedef struct {
    double period;
    double phase;
    double step;
} oscillator;

oscillator oscillators[2];


INT16 sin_table[SIN_SIZE];

void claudio_sound_init(UINT16 freq) {
    for(int i=0; i<SIN_SIZE; i++) {
        float v = sin(((float)i / SIN_SIZE) * M_PI*2);
        sin_table[i] = v * 32767;
    }

    // just for testing
    oscillator *voice = &oscillators[0];
    voice->phase  = 0;
    voice->period = (double)freq / 440.0;
    voice->step   = (double)SIN_SIZE / voice->period;
    printf("step: %f period: %f\n", voice->step, voice->period);
}

void claudio_write(UINT16 reg, UINT8 val) {
}

void claudio_process(INT16 *buffer, UINT16 size) {
    oscillator *voice = &oscillators[0];
    for(int i=0; i<size; i+=2) {
        INT16 value = sin_table[(int)voice->phase];
        buffer[i] = value;
        buffer[i+1] = value;

        voice->phase += voice->step;
        if (voice->phase >= SIN_SIZE) voice->phase -= SIN_SIZE;
    }
}