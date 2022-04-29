#include "emu.h"
#include "claudio.h"

void claudio_sound_init(UINT16 freq) {
}

void claudio_write(UINT16 reg, UINT8 val) {
}

void claudio_process(INT16 *buffer, UINT16 size) {
    for(int i=0; i<size; i++) {
        buffer[i] = 0;
    }
}