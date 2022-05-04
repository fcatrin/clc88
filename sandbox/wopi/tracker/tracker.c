#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "../emu.h"
#include "../sound/wopi.h"
#include "tracker.h"
#include "tracker_utils.h"
#include "song.h"
#include "pattern.h"

/*
    note range : 108 notes
    A0 :  27.5 Hz
    B8 : 7902.133 Hz

    https://en.wikipedia.org/wiki/Piano_key_frequencies
*/

#define FREQ_A0 27.5
#define NOTES 108
#define MS_PER_FRAME 16.6

static UINT16 freq_table[NOTES];

song_t *song;

void tracker_init() {
    float freq = FREQ_A0;
    for(int i=0; i<NOTES; i++) {
        freq_table[i] = freq;
        freq = freq * pow(2, 1.0/12);
    }

    song = song_new();
}

void load_process_line(char *line) {
    static pattern_t *current_pattern;

    line = trim(line);
    if (!strlen(line)) {
        current_pattern = NULL;
        return;
    }

    if (starts_with(line, "#")) {
        return;
    } else if (starts_with(line, "bpm")) {
        song->bpm = load_parameter_int(line, 2);
        song->ticks_per_row = (1000.0 * 60 / song->bpm / 4 / MS_PER_FRAME);
    } else if (starts_with(line, "channels")) {
        song->channels = load_parameter_int(line, 2);
    } else if (starts_with(line, "pattern")) {
        current_pattern = pattern_new();
        song_add_pattern(song, current_pattern);
    } else if (current_pattern != NULL) {
        pattern_add_row(current_pattern, song, line);
    }
}

void tracker_load(const char *filename) {
    FILE *fp = fopen(filename, "r");
    if (fp == NULL)
        exit(EXIT_FAILURE);

    char * line = NULL;
    size_t len = 0;
    ssize_t read;
    while ((read = getline(&line, &len, fp)) != -1) {
        load_process_line(line);
    }

    fclose(fp);
    if (line)
        free(line);
}

void tracker_play() {
    pattern_row_t *pattern_row = song_get_row(song);
    if (pattern_row == NULL) return;

    // just send the freq for now
    for(int i=0; i<pattern_row->channels; i++) {
        note_event_t *event = pattern_row->events[i];
        if (event != NULL && event->note != NO_NOTE) {
            UINT16 freq = freq_table[event->note];
            wopi_write(i*2+0, freq & 0xFF);
            wopi_write(i*2+1, (freq & 0xFF00) >> 8);
        }
    }
}