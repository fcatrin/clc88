#include <string.h>
#include <malloc.h>
#include "../emu.h"
#include "tracker.h"
#include "tracker_utils.h"
#include "pattern_row.h"
#include "note_event.h"

#define CHANNEL_SIZE 7

pattern_row_t *pattern_row_new(int channels) {
    // printf("pattern_row_new channels:%d\n", channels);
    pattern_row_t *pattern_row = (pattern_row_t *)malloc(sizeof(pattern_row_t));
    pattern_row->channels = channels;
    return pattern_row;
}

void pattern_row_load(pattern_row_t *pattern_row, char *line) {
    int c = 0;
    for(int i=0; i<pattern_row->channels && (c+CHANNEL_SIZE-1) < strlen(line); i++) {
        char instrument_number_desc[3];
        instrument_number_desc[0] = line[c+0];
        instrument_number_desc[1] = line[c+1];

        int instrument_index = 0;
        if (instrument_number_desc[0] != ' ') {
            instrument_index = hex2int(instrument_number_desc);
        }

        char note      = line[c+3];
        char accident  = line[c+4];
        char octave    = line[c+5];
        // printf("row_load ch:%d %c%c%c\n", i, note, accident, octave);

        char fx = line[c+7];
        char fx_op1 = line[c+8];
        char fx_op2 = line[c+9];
        char fx_op3 = line[c+10];
        UINT16 set_volume = 0;
        if (fx == 'C') {
            set_volume = 0x100 | (hexchar2int(fx_op2)*16 + hexchar2int(fx_op3));
        }

        note_event_t *event = note_event_new();
        note_event_init(event, instrument_index, note, accident, octave);
        event->set_volume = set_volume;
        pattern_row->events[i] = event;
        c+= CHANNEL_SIZE;
    }
}

void pattern_row_dump(pattern_row_t *pattern_row) {
    for(int i=0; i<pattern_row->channels; i++) {
        note_event_t *event = pattern_row->events[i];
        printf("ch:%d ", i);
        note_event_dump(event);
    }
    printf("\n");
}