#ifndef __TRACKER_H
#define __TRACKER_H

#define ROWS_PER_PATTERN 64

typedef struct {
    UINT8 note;
} note_event_t;

typedef struct {
    note_event_t *events;
} pattern_row_t;

typedef struct {
    pattern_row_t *rows[ROWS_PER_PATTERN];
    int rows_count;
} pattern_t;

typedef struct {
    UINT8 channels;
    UINT8 bpm;
    pattern_t *patterns[128];
    int patterns_index[128];
    int patterns_count;
} song_t;

void tracker_init();
void tracker_load(const char *filename);

#endif