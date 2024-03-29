#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
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

#define WOPI_PORT_PERIOD         0x000
#define WOPI_PORT_NOTE_ON        0x020
#define WOPI_PORT_VOLUME         0x030
#define WOPI_PORT_ALGORITHM      0x040
#define WOPI_PORT_OPI_WAVE_TYPE  0x050
#define WOPI_PORT_OPI_MULTIPLIER 0x080
#define WOPI_PORT_OPI_VOLUME     0x0B0
#define WOPI_PORT_OPI_ADSR       0x100

static UINT16 freq_table[NOTES];

song_t *song;

void tracker_init() {
    float freq = FREQ_A0;
    for(int i=0; i<NOTES; i++) {
        freq_table[i] = WOPI_CLK / freq;
        freq = freq * pow(2, 1.0/12);
    }

    song = song_new();
}

void load_process_line(char *line) {
    static pattern_t *current_pattern;

    if (!strlen(trim(line))) {
        printf("empty line, reset pattern\n");
        current_pattern = NULL;
        return;
    }

    if (starts_with(line, "#")) {
        return;
    } else if (starts_with(line, "bpm")) {
        song->bpm = load_parameter_int(line, 2);
        song->ticks_per_row = (1000.0 * 60 / song->bpm / 4 / MS_PER_FRAME);
        song->playing_tick = song->ticks_per_row; // start ASAP
    } else if (starts_with(line, "channels")) {
        song->channels = load_parameter_int(line, 2);
    } else if (starts_with(line, "instrument")) {
        song_register_instrument(song, line);
    } else if (starts_with(line, "patterns")) {
        song_register_patterns(song, line);
    } else if (starts_with(line, "pattern")) {
        printf("new pattern\n");
        current_pattern = pattern_new();
        song_add_pattern(song, current_pattern);
    } else if (current_pattern != NULL) {
        // printf("read row %s\n", line);
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

    song_dump(song);
}

void tracker_play() {
    song_dump_playing(song);
    pattern_row_t *pattern_row = song_get_row(song);
    if (pattern_row == NULL) return;

    // just send the freq for now
    for(int i=0; i<pattern_row->channels; i++) {
        // channel_status_t *channel_status = &song->channel_status[i];

        note_event_t *event = pattern_row->events[i];
        if (event != NULL) {
            if (event->instrument != 0) {
                instrument_t *instrument = song->instruments[event->instrument];
                if (instrument != NULL) {
                    wopi_write(WOPI_PORT_VOLUME + i, instrument->volume);
                    wopi_write(WOPI_PORT_ALGORITHM + i, instrument->algorithm);
                    for(int opi_index = 0; opi_index < MAX_OPERATORS; opi_index++) {
                        opi_t *opi = &instrument->opis[opi_index];
                        int opi_offset = i*MAX_OPERATORS + opi_index;

                        enum wave_type_t wave_type = opi->wave_type;
                        wopi_write(WOPI_PORT_OPI_WAVE_TYPE + opi_offset, wave_type & 0x03);

                        adsr_t *adsr = &opi->adsr;
                        wopi_write(WOPI_PORT_OPI_ADSR + opi_offset * 2 + 0, (adsr->attack  << 4) | adsr->decay);
                        wopi_write(WOPI_PORT_OPI_ADSR + opi_offset * 2 + 1, (adsr->sustain << 4) | adsr->release);

                        wopi_write(WOPI_PORT_OPI_MULTIPLIER + opi_offset, opi->multiplier);
                        wopi_write(WOPI_PORT_OPI_VOLUME + opi_offset, opi->volume);

                    }
                }
            }
            if (event->note != NO_NOTE) {
                UINT16 freq = freq_table[event->note];
                printf("wopi write channel %d freq %d\n", i, freq);
                wopi_write(WOPI_PORT_PERIOD + i*2+0, freq & 0xFF);
                wopi_write(WOPI_PORT_PERIOD + i*2+1, (freq & 0xFF00) >> 8);
                // note off to force an envelope reset
                wopi_write(WOPI_PORT_NOTE_ON + i, 0);
            }
            wopi_write(WOPI_PORT_NOTE_ON + i, event->note_on ? 1 : 0);

            if (event->set_volume & 0x100) {
                wopi_write(WOPI_PORT_VOLUME + i, event->set_volume & 0xff);
            }

        }
    }
}

char *wave_type_names[] = {"sin", "saw", "tri", "sqr"};

char *tracker_get_wave_type_desc(int wave_type) {
    if (wave_type >= 0 && wave_type < WAVE_TYPES) {
        return wave_type_names[wave_type];
    }
    return NULL;
}
int tracker_get_wave_type(char *desc) {
    for(int i = 0; i < WAVE_TYPES; i++) {
        if (!strcmp(desc, wave_type_names[i])) return i;
    }
    return WAVE_TYPE_SIN;
}