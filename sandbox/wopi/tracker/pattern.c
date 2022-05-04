#include <malloc.h>
#include "../emu.h"
#include "tracker.h"
#include "pattern.h"
#include "pattern_row.h"

pattern_t *pattern_new() {
    pattern_t *pattern = (pattern_t *)malloc(sizeof(pattern_t));
    pattern->rows_count = 0;
    return pattern;
}

void pattern_add_row(pattern_t *pattern, song_t *song, char *line) {
    if (pattern->rows_count >= ROWS_PER_PATTERN) return;

    pattern_row_t *row = pattern_row_new(song->channels);
    pattern->rows[pattern->rows_count++] = row;
    pattern_row_load(row, line);
}