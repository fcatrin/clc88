#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "../emu.h"
#include "tracker.h"
#include "tracker_utils.h"

/*
    note range : 108 notes
    A0 :  27.5 Hz
    B8 : 7902.133 Hz

    https://en.wikipedia.org/wiki/Piano_key_frequencies
*/

#define FREQ_A0 27.5
#define NOTES 108

static UINT16 freq_table[NOTES];

song_t song;

void tracker_init() {
    float freq = FREQ_A0;
    for(int i=0; i<NOTES; i++) {
        freq_table[i] = freq;
        freq = freq * pow(2, 1.0/12);
    }
}

void load_process_line(char *line) {
    line = trim(line);
    if (!strlen(line)) return;

    if (starts_with(line, "bpm")) {
        song.bpm = load_parameter_int(line, 2);
    } else if (starts_with(line, "channels")) {
        song.channels = load_parameter_int(line, 2);
    }
    printf("bpm: %d channels:%d\n", song.bpm, song.channels);
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
