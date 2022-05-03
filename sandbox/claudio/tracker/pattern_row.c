#include <malloc.h>
#include "../emu.h"
#include "tracker.h"
#include "pattern_row.h"

pattern_row_t *pattern_row_new(int channels) {
    pattern_row_t *pattern_row = (pattern_row_t *)malloc(sizeof(pattern_row_t));
    pattern_row->events = (note_event_t *)malloc(sizeof(note_event_t) * channels);
    return pattern_row;
}

void pattern_row_load(pattern_row_t *pattern_row, char *line) {
}