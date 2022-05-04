#include <malloc.h>
#include "../emu.h"
#include "tracker.h"
#include "song.h"

song_t *song_new() {
    song_t *song = (song_t *)malloc(sizeof(song_t));
    song->patterns_count = 0;
    return song;
}

void song_add_pattern(song_t *song, pattern_t *pattern) {
    song->patterns[song->patterns_count++] = pattern;
}