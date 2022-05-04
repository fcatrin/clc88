#ifndef __TRACKER_H
#define __TRACKER_H

#define ROWS_PER_PATTERN 64
#define MAX_CHANNELS 9
#define NO_NOTE 0xff

typedef struct {
    UINT8 note;
    bool  sustain;
} note_event_t;

typedef struct {
    note_event_t *events[MAX_CHANNELS];
    int channels;
} pattern_row_t;

typedef struct {
    pattern_row_t *rows[ROWS_PER_PATTERN];
    int rows_count;

    int playing_row;
} pattern_t;

typedef struct {
    UINT8 channels;
    UINT8 bpm;
    UINT8 ticks_per_row;

    pattern_t *patterns[128];
    int patterns_index[128];
    int patterns_count;

    int playing_pattern;
    int playing_tick;
} song_t;

void tracker_init();
void tracker_load(const char *filename);
void tracker_play();

#endif