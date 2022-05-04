#include <string.h>
#include <malloc.h>
#include "../emu.h"
#include "tracker.h"
#include "pattern_row.h"
#include "note_event.h"

pattern_row_t *pattern_row_new(int channels) {
    printf("pattern_row_new channels:%d\n", channels);
    pattern_row_t *pattern_row = (pattern_row_t *)malloc(sizeof(pattern_row_t));
    pattern_row->channels = channels;
    return pattern_row;
}

void pattern_row_load(pattern_row_t *pattern_row, char *line) {
    int c = 0;
    for(int i=0; i<pattern_row->channels && (c+2) < strlen(line); i++) {
        char note      = line[c+0];
        char accident  = line[c+1];
        char octave    = line[c+2];
        printf("row_load ch:%d %c%c%c\n", i, note, accident, octave);

        note_event_t *event = note_event_new();
        note_event_init(event, note, accident, octave);
        pattern_row->events[i] = event;
        c+= 4;
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