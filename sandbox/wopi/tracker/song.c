#include <malloc.h>
#include "../emu.h"
#include "tracker.h"
#include "song.h"
#include "pattern.h"

song_t *song_new() {
    song_t *song = (song_t *)malloc(sizeof(song_t));
    song->patterns_count = 0;
    return song;
}

void song_add_pattern(song_t *song, pattern_t *pattern) {
    song->patterns[song->patterns_count++] = pattern;
}

static pattern_row_t *get_next_row(song_t *song) {
    pattern_row_t *pattern_row;
    do {
        if (song->playing_pattern >= song->patterns_count) {
            song->playing_pattern = 0; // just restart for now
        }

        int playing_pattern_index = song->patterns_index[song->playing_pattern];
        pattern_t *pattern = song->patterns[playing_pattern_index];
        pattern_row = pattern_get_next_row(pattern);
        if (pattern_row == NULL) {
            song->playing_pattern++;
        }
    } while (pattern_row == NULL); // loop until we get the next row
    return pattern_row;
}

pattern_row_t *song_get_row(song_t *song) {
    song->playing_tick++;
    if (song->playing_tick < song->ticks_per_row) return NULL;

    song->playing_tick = 0;
    return get_next_row(song);
}