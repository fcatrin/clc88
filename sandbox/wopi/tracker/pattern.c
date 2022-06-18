#include <malloc.h>
#include <string.h>
#include "../emu.h"
#include "tracker.h"
#include "pattern.h"
#include "pattern_row.h"

pattern_t *pattern_new() {
    NEW(pattern, pattern_t);
    pattern->rows_count = 0;
    return pattern;
}

void pattern_add_row(pattern_t *pattern, song_t *song, char *line) {
    if (pattern->rows_count >= ROWS_PER_PATTERN) return;

    // printf("add row[%d]\n", pattern->rows_count);
    pattern_row_t *row = pattern_row_new(song->channels);
    pattern->rows[pattern->rows_count++] = row;
    pattern_row_load(row, line);
}

pattern_row_t *pattern_get_next_row(pattern_t *pattern) {
    if (pattern->playing_row >= ROWS_PER_PATTERN) {
        printf("end of pattern\n");
        pattern->playing_row = 0;
        return NULL;
    }

    // printf("pattern at row %d\n", pattern->playing_row);
    return pattern->rows[pattern->playing_row++];
}

void pattern_dump(pattern_t *pattern) {
    printf("pattern rows_count:%d\n", pattern->rows_count);
    for(int i=0; i<pattern->rows_count; i++) {
        pattern_row_t *row = pattern->rows[i];
        printf("pattern row:%d ", i);
        pattern_row_dump(row);
    }
}

void pattern_dump_playing(pattern_t *pattern) {
    printf("pattern playing rows:%d", pattern->playing_row);
}