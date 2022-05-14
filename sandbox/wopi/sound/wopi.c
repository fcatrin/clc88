#include <stdio.h>
#include <math.h>
#include "emu.h"
#include "wopi.h"

/*
    CLK = 100MHz / 56 = 1.785714 MHz   (Compy system clock is 100MHz)
    This is probably the closest to the typical clock rates for audio chips on the eighties:

    - MSX NTSC 1.789772 MHz
    - NES NTSC 1.789773 MHz
    - NES PAL  1.662607 MHz

    Base waveform
    =============
    Hardware implementation will use a precalculated sine wave. Using 2048 points
    gives a lower frequency of 21,53Hz for 44.1 KHz sampling rate. Good enough

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
    bits 4-0 : static volume
    bit  6   : use envelope if 1
    bit  7   : note on if 1

*/

#define CLK WOPI_CLK
#define WAVE_SIZE 2048
#define WAVE_HALF (WAVE_SIZE / 2)
#define VOICES 9
#define OPIS 4

#define WAVE_TYPE_SIN 0
#define WAVE_TYPE_SAW 1
#define WAVE_TYPE_TRI 2
#define WAVE_TYPE_SQR 3

#define ENV_ATTACK   0
#define ENV_DECAY    1
#define ENV_SUSTAIN  2
#define ENV_RELEASE  3
#define ENV_COMPLETE 4

typedef struct {
    float period;
    float phase;
    UINT8 wave_type;

    bool  envelope;
    UINT8 volume;

    int    env_stage;
    UINT8  env_attack;
    UINT8  env_decay;
    UINT8  env_sustain;
    UINT8  env_release;
    UINT32 env_stop;
    float  env_phase;
    float  env_step;
    UINT8  env_volume;
    UINT8  env_volume_release;
} opi_t;

typedef struct {
    UINT16 divider;
    bool  note_on;
    opi_t opis[OPIS];
} voice_t;

static voice_t voices[VOICES];

static INT16 sin_table[WAVE_SIZE];

#define ENVELOPE_STAGE_SIZE 256
#define ENVELOPE_STAGE_VALUES 16
#define ENVELOPE_VALUE_MAX 255
#define ENVELOPE_VALUE_MIN 0
static UINT8 asc_table[ENVELOPE_STAGE_SIZE]; // ascending curve used in attack
static UINT8 des_table[ENVELOPE_STAGE_SIZE]; // descending curve used in release and decay
static float att_step[ENVELOPE_STAGE_VALUES];
static float dec_step[ENVELOPE_STAGE_VALUES];
static float rel_step[ENVELOPE_STAGE_VALUES];
static UINT32 att_stop[ENVELOPE_STAGE_VALUES];
static UINT32 rel_stop[ENVELOPE_STAGE_VALUES];

static void set_note_on(voice_t *voice, UINT8 value);
static void set_period_low (voice_t *voice, UINT8 value);
static void set_period_high(voice_t *voice, UINT8 value);
static void set_volume_reg(opi_t *opi, UINT8 value);
static void set_wave_type(opi_t *opi, UINT8 wave_type);
static void set_env_ad(opi_t *opi, UINT8 value);
static void set_env_sr(opi_t *opi, UINT8 value);
static void env_start_stage(opi_t *opi, int stage);

static UINT16 sampling_freq;

#define MIN_DEBUG_ENV 6000
#define MAX_DEBUG_ENV 5000
static int debug_env = 0;

void wopi_sound_init(UINT16 freq) {
    sampling_freq = freq;

    for(int i=0; i<WAVE_SIZE; i++) {
        float v = sin(((float)i / WAVE_SIZE) * M_PI*2);
        sin_table[i] = v * 32767;
    }

    // log descending ratio
    // ratio = (last / first) ^ (1/(N - 1))
    // https://www.quora.com/How-do-you-find-the-common-ratio-with-the-first-and-last-terms
    float des_ratio = pow((ENVELOPE_VALUE_MIN+1) / (float)ENVELOPE_VALUE_MAX, (1.0 / (ENVELOPE_STAGE_SIZE-1)));
    float des_value = ENVELOPE_VALUE_MAX;

    // create tables for envelope ascending and descending curves
    for(int i=0; i<ENVELOPE_STAGE_SIZE; i++) {
        // use 1/4 sine as ascending function
        asc_table[i] = (UINT8)((ENVELOPE_VALUE_MAX+1) * sin(((float)i / 4 / ENVELOPE_STAGE_SIZE) * M_PI*2));

        // use log descending
        des_table[i] = des_value;
        des_value *= des_ratio;
    }

    // create tables for "steps" required on each envelope value
    float att_time = 2500.0;
    float dec_time = 5500.0;
    float rel_time = 8000.0;
    int last_index = ENVELOPE_STAGE_SIZE-1;
    for(int i=0; i<ENVELOPE_STAGE_VALUES; i++) {
        att_stop[i] = att_time / 1000.0 * freq;
        att_step[i] = last_index / (float)att_stop[i];
        printf("att_step[%d] = %f att_stop[%d] = %d\n", i, att_step[i], i, att_stop[i]);
        att_time /= 2.0; // log scale  1.4 according to https://github.com/jotego/jt51/blob/master/doc/envelope.ods

        dec_step[i] = last_index / (dec_time / 1000.0 * freq);
        if (dec_time > 2) dec_time /= 2.0; // log scale stopping at 2ms

        rel_stop[i] = (rel_time / 1000.0 * freq);
        rel_step[i] = last_index / (float)rel_stop[i];
        rel_time /= 2.0; // log scale
    }

    // wopi_write(0, 8116 & 0xff);
    // wopi_write(1, 8116 >> 8);
    for(int i=0; i<VOICES; i++) {
        wopi_write(128+i, 0);
    }

}

opi_t *get_opi_by_index(int index) {
    int voice_index = index / OPIS;
    int opi_index = index % OPIS;
    return &voices[voice_index].opis[opi_index];
}

void wopi_write(UINT16 reg, UINT8 value) {
    reg = reg & 0x1FF;
    if (reg < (VOICES*2)) {  // 16 bit per voice
        voice_t *voice = &voices[reg / 2];
        int part = reg & 1;
        if (part == 0) {
            set_period_low(voice, value);
        } else {
            set_period_high(voice, value);
        }
    } else if (reg < 18 + VOICES) {
        voice_t *voice = &voices[reg - 18];
        set_note_on(voice, value);
    } else if (reg < 128 + (VOICES*OPIS)) { // 128 - 163
        opi_t *opi = get_opi_by_index(reg - 128);
        set_volume_reg(opi, value);
    } else if (reg < 164 + VOICES) { // 164 - 173
        opi_t *opi = get_opi_by_index(reg - 164);
        set_wave_type(opi, value);
    } else if (reg < 180 + (VOICES*OPIS)*2) { // 180 - 252
        opi_t *opi = get_opi_by_index(reg - 180);
        if (reg & 1) set_env_sr(opi, value);
        else set_env_ad(opi, value);
    }
}

static void update_period(voice_t *voice){
    if (voice->divider == 0) return;
    for(int i=0; i<OPIS; i++) {
        voice->opis[i].period = (CLK / voice->divider) * ((float)WAVE_SIZE / sampling_freq);
    }
}

static void set_period_low(voice_t *voice, UINT8 value) {
    voice->divider = (voice->divider & 0xff00) | value;
    update_period(voice);
}

static void set_period_high(voice_t *voice, UINT8 value) {
    voice->divider = (voice->divider & 0x00ff) | (value << 8);
    update_period(voice);
}

static void set_volume_reg(opi_t *opi, UINT8 value) {
    opi->volume   = value & 0x3f;
    opi->envelope = value & 0x40;
}

static void voice_env_start_stage(voice_t *voice, UINT8 stage) {
    for(int i=0; i<OPIS; i++) {
        env_start_stage(&voice->opis[i], stage);
    }
}

static void set_note_on(voice_t *voice, UINT8 value) {
    bool note_on_next  = value & 0x01;
    if (!voice->note_on && note_on_next) {
        voice->note_on = TRUE;
        voice_env_start_stage(voice, ENV_ATTACK);
        debug_env = 0;
    } else if (voice->note_on && !note_on_next) {
        voice->note_on = FALSE;
        voice_env_start_stage(voice, ENV_RELEASE);
    }
}

static void set_wave_type(opi_t *opi, UINT8 wave_type) {
    opi->wave_type = wave_type;
}

static void set_env_ad(opi_t *opi, UINT8 value) {
    opi->env_attack = (value & 0xF0) >> 4;
    opi->env_decay  = (value & 0x0F);
    env_start_stage(opi, ENV_ATTACK);
}

static void set_env_sr(opi_t *opi, UINT8 value) {
    opi->env_sustain = (value & 0xF0) >> 4;
    opi->env_release = (value & 0x0F);
    env_start_stage(opi, ENV_ATTACK);
}

static void env_start_stage(opi_t *opi, int stage) {
    opi->env_stage = stage;
    opi->env_phase = 0;
    if (stage == ENV_ATTACK) {
        opi->env_step  = att_step[opi->env_attack];
        opi->env_stop  = att_stop[opi->env_attack];
    } else if (stage == ENV_DECAY) {
        opi->env_step  = dec_step[opi->env_decay];
        opi->env_stop  = 0;
    } else if (stage == ENV_RELEASE) {
        opi->env_volume_release = opi->env_volume;
        opi->env_step  = rel_step[opi->env_release];
        opi->env_stop  = rel_stop[opi->env_release];
    }
}

static bool is_debug_env() {
    return debug_env >= MIN_DEBUG_ENV && debug_env <= MAX_DEBUG_ENV;
}

static void resolve_envelope_value(opi_t *opi) {
    if (!opi->envelope) {
        if (is_debug_env()) printf("no envelope ");
        opi->env_volume = 255;
        return;
    }

    if (opi->env_stage == ENV_ATTACK) {
        if (is_debug_env()) printf("attack envelope phase:%f stop:%d ", opi->env_phase, opi->env_stop);
        opi->env_volume = asc_table[(int)opi->env_phase];
        opi->env_phase += opi->env_step;
        if (opi->env_stop-- == 0) env_start_stage(opi, ENV_DECAY);
    } else if (opi->env_stage == ENV_DECAY) {
        if (is_debug_env()) printf("decay envelope phase:%f target sustain:%d ", opi->env_phase, (opi->env_sustain << 4 | 0x0f));
        opi->env_volume = des_table[(int)opi->env_phase];
        opi->env_phase += opi->env_step;
        if (opi->env_volume >> 4 == opi->env_sustain) opi->env_stage = ENV_SUSTAIN;
    } else if (opi->env_stage == ENV_SUSTAIN) {
        opi->env_volume = opi->env_sustain << 4 | 0x0f;
        if (is_debug_env()) printf("sustain envelope volume:%d ", opi->env_volume);
    } else if (opi->env_stage == ENV_RELEASE) {
        opi->env_volume = des_table[(int)opi->env_phase] * (float)(opi->env_volume_release / 255.0);
        if (is_debug_env()) printf("release envelope phase:%f stop:%d tab:%d", opi->env_phase, opi->env_stop, des_table[(int)opi->env_phase]);
        opi->env_phase += opi->env_step;
        if (opi->env_volume == 0) opi->env_stage = ENV_COMPLETE;
    }
}

void wopi_process(INT16 *buffer, UINT16 size) {
    for(int i=0; i<size; i+=2) {
        buffer[i+0] = 0;
        buffer[i+1] = 0;

        for(int voice_index = 0; voice_index < 1; voice_index++) {
            for(int opi_index = 0; opi_index < 1; opi_index++) {
                opi_t *opi = &voices[voice_index].opis[opi_index];

                int opi_value = 0;
                switch(opi->wave_type) {
                    case WAVE_TYPE_SIN : opi_value = sin_table[(int)opi->phase]; break;
                    case WAVE_TYPE_SAW : opi_value = (opi->phase - WAVE_HALF) * 32; break;
                    case WAVE_TYPE_TRI : opi_value = opi->phase < WAVE_HALF ? (opi->phase*2 - WAVE_HALF) * 32 : (WAVE_SIZE - opi->phase*2) * 32 ; break;
                    case WAVE_TYPE_SQR : opi_value = opi->phase < WAVE_HALF ? -32767 : 32767; break;
                }

                opi_value >>= 1;

                resolve_envelope_value(opi);
                UINT8  env_value = opi->env_volume;
                if (is_debug_env()) {
                    printf("env_value[%d] = %d\n", debug_env, env_value);
                }
                debug_env++;

                int voice_envelope = opi_value * (env_value / 255.0);
                int voice_final = voice_envelope;

                buffer[i+0] += voice_final;
                buffer[i+1] += voice_final;

                opi->phase += opi->period;
                if (opi->phase >= WAVE_SIZE) opi->phase -= WAVE_SIZE;
            }
        }
    }
}