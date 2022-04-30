#include <stdio.h>
#include <math.h>
#include "emu.h"
#include "claudio.h"

/*
    CLK = 100MHz / 56 = 1.785714 MHz   (Compy system clock is 100MHz)
    This is probably the closest to the typical clocks for audio chips of the eighties:

    - MSX NTSC 1.789772 MHz
    - NES NTSC 1.789773 MHz
    - NES PAL  1.662607 MHz

    Base waveform
    =============
    Hardware implementation will use a precalculated sine wave. Using 2048 points
    gives a lower frequency of 20 Hz for 44.1 KHz sampling rate. Good enough

    Target frequencies
    ==================
    Register values are 16-bit periods of the desired frequency. The period is relative
    to the base waveform (2048 points) and can be seen as:

    bits
    15-5 : integer part inside wave (11 bits)
    4-0  : decimal part

    FREQ(X) = CLK / X
    X       = CLK / FREQ

    Range is:
    FREQ(1)       = CLK / 1          =  1.7 Mhz Inaudible. Ignored
    FREQ(80)      = CLK / 80         =   22 KHz Highest audible frequency
    FREQ(65535)   = CLK / 65535      =   27 Hz  Lowest audible frequency

    Some basic examples
    FREQ = 220 => X = 8116
    FREQ = 440 => X = 4058

    Emulation
    =========
    On emulation we can scale these hardware values to the required 44100 Hz sampling rate

    EMU(X) = (CLK / X) * (2048.0 / 44100);


*/

#define CLK 1785714
#define WAVE_SIZE 2048

typedef struct {
    float period;
    float phase;
} oscillator;

oscillator oscillators[2];


INT16 sin_table[WAVE_SIZE];
INT16 tri_table[WAVE_SIZE];
INT16 saw_table[WAVE_SIZE];

void claudio_sound_init(UINT16 freq) {
    int half = WAVE_SIZE/2;
    for(int i=0; i<WAVE_SIZE; i++) {
        float v = sin(((float)i / WAVE_SIZE) * M_PI*2);
        sin_table[i] = v * 32767;

        float tri_asc = (i*2.0 / half) - 1;
        float tri_des = 1 - ((i-half)*2.0 / half);
        tri_table[i] = (i < half ? tri_asc : tri_des) * 32767;
    }

    // just for testing
    oscillator *voice = &oscillators[0];
    voice->phase  = 0;
    voice->period = (CLK / 4058.0) * (2048.0 / freq);
}

void claudio_write(UINT16 reg, UINT8 val) {
    oscillator *voice = &oscillators[0];
    switch(reg & 0x0F) {
        // case 0: voice->period = (voice->period & 0xFF00) | val; break;
        // case 1: voice->period = (voice->period & 0x00FF) | (val << 8); break;
    }
}

void claudio_process(INT16 *buffer, UINT16 size) {
    oscillator *voice = &oscillators[0];
    for(int i=0; i<size; i+=2) {
        INT16 value = tri_table[(int)voice->phase];
        buffer[i] = value;
        buffer[i+1] = value;

        voice->phase += voice->period;
        if (voice->phase >= WAVE_SIZE) voice->phase -= WAVE_SIZE;
    }
}