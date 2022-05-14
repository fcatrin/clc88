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
#define OPERATORS 4

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
} operator_t;

typedef struct {
    UINT16 divider;
    bool  note_on;
    operator_t operators[OPERATORS];
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
static void set_volume_reg(operator_t *operator, UINT8 value);
static void set_wave_type(operator_t *operator, UINT8 wave_type);
static void set_env_ad(operator_t *operator, UINT8 value);
static void set_env_sr(operator_t *operator, UINT8 value);
static void env_start_stage(operator_t *operator, int stage);

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

operator_t *get_operator_by_index(int index) {
    int voice_index = index / OPERATORS;
    int operator_index = index % OPERATORS;
    return &voices[voice_index].operators[operator_index];
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
    } else if (reg < 128 + (VOICES*OPERATORS)) { // 128 - 163
        operator_t *operator = get_operator_by_index(reg - 128);
        set_volume_reg(operator, value);
    } else if (reg < 164 + VOICES) { // 164 - 173
        operator_t *operator = get_operator_by_index(reg - 164);
        set_wave_type(operator, value);
    } else if (reg < 180 + (VOICES*OPERATORS)*2) { // 180 - 252
        operator_t *operator = get_operator_by_index(reg - 180);
        if (reg & 1) set_env_sr(operator, value);
        else set_env_ad(operator, value);
    }
}

static void update_period(voice_t *voice){
    if (voice->divider == 0) return;
    for(int i=0; i<OPERATORS; i++) {
        voice->operators[i].period = (CLK / voice->divider) * ((float)WAVE_SIZE / sampling_freq);
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

static void set_volume_reg(operator_t *operator, UINT8 value) {
    operator->volume   = value & 0x3f;
    operator->envelope = value & 0x40;
}

static void voice_env_start_stage(voice_t *voice, UINT8 stage) {
    for(int i=0; i<OPERATORS; i++) {
        env_start_stage(&voice->operators[i], stage);
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

static void set_wave_type(operator_t *operator, UINT8 wave_type) {
    operator->wave_type = wave_type;
}

static void set_env_ad(operator_t *operator, UINT8 value) {
    operator->env_attack = (value & 0xF0) >> 4;
    operator->env_decay  = (value & 0x0F);
    env_start_stage(operator, ENV_ATTACK);
}

static void set_env_sr(operator_t *operator, UINT8 value) {
    operator->env_sustain = (value & 0xF0) >> 4;
    operator->env_release = (value & 0x0F);
    env_start_stage(operator, ENV_ATTACK);
}

static void env_start_stage(operator_t *operator, int stage) {
    operator->env_stage = stage;
    operator->env_phase = 0;
    if (stage == ENV_ATTACK) {
        operator->env_step  = att_step[operator->env_attack];
        operator->env_stop  = att_stop[operator->env_attack];
    } else if (stage == ENV_DECAY) {
        operator->env_step  = dec_step[operator->env_decay];
        operator->env_stop  = 0;
    } else if (stage == ENV_RELEASE) {
        operator->env_volume_release = operator->env_volume;
        operator->env_step  = rel_step[operator->env_release];
        operator->env_stop  = rel_stop[operator->env_release];
    }
}

static bool is_debug_env() {
    return debug_env >= MIN_DEBUG_ENV && debug_env <= MAX_DEBUG_ENV;
}

static void resolve_envelope_value(operator_t *operator) {
    if (!operator->envelope) {
        if (is_debug_env()) printf("no envelope ");
        operator->env_volume = 255;
        return;
    }

    if (operator->env_stage == ENV_ATTACK) {
        if (is_debug_env()) printf("attack envelope phase:%f stop:%d ", operator->env_phase, operator->env_stop);
        operator->env_volume = asc_table[(int)operator->env_phase];
        operator->env_phase += operator->env_step;
        if (operator->env_stop-- == 0) env_start_stage(operator, ENV_DECAY);
    } else if (operator->env_stage == ENV_DECAY) {
        if (is_debug_env()) printf("decay envelope phase:%f target sustain:%d ", operator->env_phase, (operator->env_sustain << 4 | 0x0f));
        operator->env_volume = des_table[(int)operator->env_phase];
        operator->env_phase += operator->env_step;
        if (operator->env_volume >> 4 == operator->env_sustain) operator->env_stage = ENV_SUSTAIN;
    } else if (operator->env_stage == ENV_SUSTAIN) {
        operator->env_volume = operator->env_sustain << 4 | 0x0f;
        if (is_debug_env()) printf("sustain envelope volume:%d ", operator->env_volume);
    } else if (operator->env_stage == ENV_RELEASE) {
        operator->env_volume = des_table[(int)operator->env_phase] * (float)(operator->env_volume_release / 255.0);
        if (is_debug_env()) printf("release envelope phase:%f stop:%d tab:%d", operator->env_phase, operator->env_stop, des_table[(int)operator->env_phase]);
        operator->env_phase += operator->env_step;
        if (operator->env_volume == 0) operator->env_stage = ENV_COMPLETE;
    }
}

void wopi_process(INT16 *buffer, UINT16 size) {
    for(int i=0; i<size; i+=2) {
        buffer[i+0] = 0;
        buffer[i+1] = 0;

        for(int voice_index = 0; voice_index < 1; voice_index++) {
            for(int operator_index = 0; operator_index < 1; operator_index++) {
                operator_t *operator = &voices[voice_index].operators[operator_index];

                int operator_value = 0;
                switch(operator->wave_type) {
                    case WAVE_TYPE_SIN : operator_value = sin_table[(int)operator->phase]; break;
                    case WAVE_TYPE_SAW : operator_value = (operator->phase - WAVE_HALF) * 32; break;
                    case WAVE_TYPE_TRI : operator_value = operator->phase < WAVE_HALF ? (operator->phase*2 - WAVE_HALF) * 32 : (WAVE_SIZE - operator->phase*2) * 32 ; break;
                    case WAVE_TYPE_SQR : operator_value = operator->phase < WAVE_HALF ? -32767 : 32767; break;
                }

                operator_value >>= 1;

                resolve_envelope_value(operator);
                UINT8  env_value = operator->env_volume;
                if (is_debug_env()) {
                    printf("env_value[%d] = %d\n", debug_env, env_value);
                }
                debug_env++;

                int voice_envelope = operator_value * (env_value / 255.0);
                int voice_final = voice_envelope;

                buffer[i+0] += voice_final;
                buffer[i+1] += voice_final;

                operator->phase += operator->period;
                if (operator->phase >= WAVE_SIZE) operator->phase -= WAVE_SIZE;
            }
        }
    }
}