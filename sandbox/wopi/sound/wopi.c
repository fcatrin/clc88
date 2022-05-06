#include <stdio.h>
#include <math.h>
#include "emu.h"
#include "wopi.h"

/*
    CLK = 100MHz / 56 = 1.785714 MHz   (Compy system clock is 100MHz)
    This is probably the closest to the typical clocks for audio chips of the eighties:

    - MSX NTSC 1.789772 MHz
    - NES NTSC 1.789773 MHz
    - NES PAL  1.662607 MHz

    Base waveform
    =============
    Hardware implementation will use a precalculated sine wave. Using 2048 points
    gives a lower frequency of 20 Hz for 44.1 KHz sampling rate. Good enough

    Target frequencies
    ==================
    Register values are 16-bit periods of the desired frequency. The period is relative
    to the base waveform (2048 points) and can be seen as:

    bits
    15-5 : integer part inside wave (11 bits)
    4-0  : decimal part

    FREQ(X) = CLK / X
    X       = CLK / FREQ

    Range is:
    FREQ(1)       = CLK / 1          =  1.7 Mhz Inaudible. Ignored
    FREQ(80)      = CLK / 80         =   22 KHz Highest audible frequency
    FREQ(65535)   = CLK / 65535      =   27 Hz  Lowest audible frequency

    Some basic examples
    FREQ = 220 => X = 8116
    FREQ = 440 => X = 4058

    Emulation
    =========
    On emulation we can scale these hardware values to the required 44100 Hz sampling rate

    EMU(X) = (CLK / X) * (2048.0 / 44100);

    Volume
    ======
    bits 6-0 : static volume
    bit  7   : use envelope if 1

*/

#define CLK WOPI_CLK
#define WAVE_SIZE 2048
#define VOICES 9
#define OPERATORS 4

#define WAVE_TYPE_SIN 0
#define WAVE_TYPE_SAW 1
#define WAVE_TYPE_TRI 2
#define WAVE_TYPE_SQR 3

typedef struct {
    UINT16 divider;
    float period;
    float phase;
    UINT8 volume;
    UINT8 wave_type;
} osc;

static osc oscs[VOICES * OPERATORS];

static INT16 sin_table[WAVE_SIZE];
static INT16 tri_table[WAVE_SIZE];
static INT16 saw_table[WAVE_SIZE];
static INT16 sqr_table[WAVE_SIZE];

#define ENVELOPE_STAGE_SIZE 256
static UINT8 asc_table[ENVELOPE_STAGE_SIZE]; // ascending curve used in attack
static UINT8 des_table[ENVELOPE_STAGE_SIZE]; // descending curve used in release and decay
static UINT8 att_table[ENVELOPE_STAGE_SIZE]; // 2s log
static UINT8 dec_table[ENVELOPE_STAGE_SIZE]; // 5s log
static UINT8 rel_table[ENVELOPE_STAGE_SIZE]; // 8s log


static void set_period_low (int osc_index, UINT8 value);
static void set_period_high(int osc_index, UINT8 value);
static void set_volume(int osc_index, UINT8 value);
static void set_wave_type(int osc_index, UINT8 wave_type);

static UINT16 sampling_freq;

void wopi_sound_init(UINT16 freq) {
    sampling_freq = freq;

    int half = WAVE_SIZE/2;
    for(int i=0; i<WAVE_SIZE; i++) {
        float v = sin(((float)i / WAVE_SIZE) * M_PI*2);
        sin_table[i] = v * 32767;

        float tri_asc = (i*2.0 / half) - 1;
        float tri_des = 1 - ((i-half)*2.0 / half);
        tri_table[i] = (i < half ? tri_asc : tri_des) * 32767;

        saw_table[i] = ((i*2.0 / WAVE_SIZE) - 1) * 32767;;
        sqr_table[i] = (i < half ? -1 : 1) * 32767;
    }

    for(int i=0; i< ENVELOPE_STAGE_SIZE; i++) {
        // use 1/4 sine as ascending function
        asc_table[i] = (UINT8)(256.0 * sin(((float)i / 4 / ENVELOPE_STAGE_SIZE) * M_PI*2));
        // use linear descending
        des_table[i] = 255.0 - (255.0 * (float)i/ENVELOPE_STAGE_SIZE);
    }

    // wopi_write(0, 8116 & 0xff);
    // wopi_write(1, 8116 >> 8);
    for(int i=0; i<VOICES; i++) {
        wopi_write(128+i, 12);
    }

}

void wopi_write(UINT16 reg, UINT8 value) {
    reg = reg & 0xFF;
    if (reg < (VOICES*OPERATORS*2)) {  // 36 oscillators * 2
        int osc_index = reg / 2;
        int part = reg & 1;
        if (part == 0) {
            set_period_low(osc_index, value);
        } else {
            set_period_high(osc_index, value);
        }
    } else if (reg < 128 + (VOICES*OPERATORS)) {
        int osc_index = reg - 128;
        set_volume(osc_index, value);
    } else if (reg < 128 + (VOICES*OPERATORS) + VOICES) {
        int osc_index = reg - 128 - (VOICES*OPERATORS);
        set_wave_type(osc_index, value);
    }
}

static void update_period(osc *osc){
    if (osc->divider == 0) return;
    osc->period = (CLK / osc->divider) * ((float)WAVE_SIZE / sampling_freq);
}

static void set_period_low(int osc_index, UINT8 value) {
    osc *osc = &oscs[osc_index];
    osc->divider = (osc->divider & 0xff00) | value;
    update_period(osc);
}

static void set_period_high(int osc_index, UINT8 value) {
    osc *osc = &oscs[osc_index];
    osc->divider = (osc->divider & 0x00ff) | (value << 8);
    update_period(osc);
}

static void set_volume(int osc_index, UINT8 value) {
    osc *osc = &oscs[osc_index];
    osc->volume = value;
}

static void set_wave_type(int osc_index, UINT8 wave_type) {
    osc *osc = &oscs[osc_index];
    osc->wave_type = wave_type;
}

void wopi_process(INT16 *buffer, UINT16 size) {
    for(int i=0; i<size; i+=2) {
        buffer[i+0] = 0;
        buffer[i+1] = 0;

        for(int v=0; v < VOICES; v++) {
            osc *voice = &oscs[v];

            INT16 *wave_table = NULL;
            switch(voice->wave_type) {
                case WAVE_TYPE_SIN : wave_table = sin_table; break;
                case WAVE_TYPE_SAW : wave_table = saw_table; break;
                case WAVE_TYPE_TRI : wave_table = tri_table; break;
                case WAVE_TYPE_SQR : wave_table = sqr_table; break;
            }
            INT16 value = wave_table == NULL ? 0 : (wave_table[(int)voice->phase] * (voice->volume / 128.0));
            buffer[i+0] += value;
            buffer[i+1] += value;

            voice->phase += voice->period;
            if (voice->phase >= WAVE_SIZE) voice->phase -= WAVE_SIZE;
        }
    }
}