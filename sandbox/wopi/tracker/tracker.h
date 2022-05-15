#ifndef __TRACKER_H
#define __TRACKER_H

#define ROWS_PER_PATTERN 64
#define MAX_CHANNELS 9
#define MAX_INSTRUMENTS 128
#define MAX_OPERATORS 4
#define NO_NOTE 0xff

enum wave_type_t {
    WAVE_TYPE_SIN, WAVE_TYPE_SAW, WAVE_TYPE_TRI, WAVE_TYPE_SQR,
    WAVE_TYPES
};

typedef struct {
    UINT8 attack;
    UINT8 decay;
    UINT8 sustain;
    UINT8 release;
} adsr_t;

typedef struct {
    enum wave_type_t wave_type;
    bool has_envelope;
    UINT8 multiplier;
    adsr_t adsr;
} opi_t;

typedef struct {
    opi_t opis[MAX_OPERATORS];
} instrument_t;

typedef struct {
    UINT8 note;
    UINT8 volume;
    int   instrument;
    bool  note_on;
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
    // bool  has_envelope;
} channel_status_t;

typedef struct {
    UINT8 channels;
    UINT8 bpm;
    UINT8 ticks_per_row;

    pattern_t *patterns[128];
    int patterns_index[128];
    int patterns_count;

    instrument_t *instruments[MAX_INSTRUMENTS];
    channel_status_t channel_status[MAX_CHANNELS];

    int playing_pattern;
    int playing_tick;
} song_t;

void tracker_init();
void tracker_load(const char *filename);
void tracker_play();

char *tracker_get_wave_type_desc(int wave_type);
int   tracker_get_wave_type(char *desc);

#endif