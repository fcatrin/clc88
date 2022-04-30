#include <stdio.h>
#include <math.h>
#include "../emu.h"

/*
    note range : 108 notes
    A0 :  27.5 Hz
    B8 : 7902.133 Hz

    https://en.wikipedia.org/wiki/Piano_key_frequencies
*/

#define FREQ_A0 27.5
#define NOTES 108

static UINT16 freq_table[NOTES];

void tracker_init() {
    float freq = FREQ_A0;
    for(int i=0; i<NOTES; i++) {
        freq_table[i] = freq;
        freq = freq * pow(2, 1.0/12);
    }
}