#include <stdio.h>
#include <malloc.h>
#include <string.h>
#include "../emu.h"
#include "tracker.h"
#include "tracker_utils.h"
#include "song.h"
#include "pattern.h"
#include "instrument.h"

song_t *song_new() {
    NEW(song, song_t);
    song->patterns_count = 0;
    return song;
}

void song_add_pattern(song_t *song, pattern_t *pattern) {
    song->patterns[song->patterns_count++] = pattern;
}

static pattern_row_t *get_next_row(song_t *song) {
    pattern_row_t *pattern_row;
    do {
        if (song->playing_pattern >= song->patterns_last) {
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

void song_register_patterns(song_t *song, char *line) {
    song->patterns_last = 0;
    for(int i=0; i<MAX_PATTERNS; i++) {
        int pattern_number = load_parameter_hex_with_default(line, i + 2, -1);
        if (pattern_number < 0) break;

        song->patterns_index[i] = pattern_number;
        song->patterns_last++;
    }
}

void song_register_instrument(song_t *song, char *line) {
    opi_t opis[MAX_OPERATORS];

    int instrument_number    = load_parameter_hex(line, 2);
    int instrument_volume    = load_parameter_hex(line, 3);
    int instrument_algorithm = load_parameter_hex(line, 4);
    int parameter = 5;
    for(int i=0; i<MAX_OPERATORS; i++) {
        opi_t *opi = &opis[i];
        char *wave_type_desc = load_parameter(line, parameter);
        opi->wave_type = tracker_get_wave_type(wave_type_desc);

        char *envelope_desc = load_parameter(line, parameter + 1);
        if (strlen(envelope_desc)!=4) break;

        opi->adsr.attack  = hexchar2int(envelope_desc[0]);
        opi->adsr.decay   = hexchar2int(envelope_desc[1]);
        opi->adsr.sustain = hexchar2int(envelope_desc[2]);
        opi->adsr.release = hexchar2int(envelope_desc[3]);

        char *volume_desc = load_parameter(line, parameter + 2);
        opi->volume = hex2int(volume_desc);

        char *multiplier_desc = load_parameter(line, parameter + 3);
        opi->multiplier = hex2int(multiplier_desc);

        parameter += 4;
    }

    instrument_t *instrument = instrument_new();
    instrument_init(instrument, instrument_volume, instrument_algorithm, opis);
    song->instruments[instrument_number] = instrument;
}

void song_dump(song_t *song) {
    printf("song channels:%d, bpm:%d, ticks:%d patterns:%d patterns to play:%d\n",
        song->channels, song->bpm, song->ticks_per_row, song->patterns_count, song->patterns_last
    );
    printf("song instruments:\n");
    for(int i=0; i<MAX_INSTRUMENTS; i++) {
        instrument_t *instrument = song->instruments[i];
        if (instrument == NULL) continue;
        printf("instrument[%d] = ", i);
        instrument_dump(instrument);
    }

    printf("song patterns index:");
    for(int i=0; i<song->patterns_last; i++) {
        printf(" %02x", song->patterns_index[i]);
    }
    printf("\n");

    printf("song patterns:\n");
    for(int i=0; i<song->patterns_count; i++) {
        // printf("== pattern[%d] = %d\n", i, song->patterns_index[i]);
        pattern_dump(song->patterns[i]);
        printf("\n");
    }
}

void song_dump_playing(song_t *song) {
    // printf("song playing pattern:%d tick:%d\n", song->playing_pattern, song->playing_tick);
}