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
    UINT16 divider;
    float period;
    float phase;
    UINT8 wave_type;

    bool  note_on;
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
} osc;

static osc oscs[VOICES * OPERATORS];

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

static void set_period_low (int osc_index, UINT8 value);
static void set_period_high(int osc_index, UINT8 value);
static void set_volume_reg(int osc_index, UINT8 value);
static void set_wave_type(int osc_index, UINT8 wave_type);
static void set_env_ad(int osc_index, UINT8 value);
static void set_env_sr(int osc_index, UINT8 value);
static void env_start_stage(osc *voice, int stage);

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

void wopi_write(UINT16 reg, UINT8 value) {
    reg = reg & 0x1FF;
    if (reg < (VOICES*OPERATORS*2)) {  // 36 oscillators * 2
        int osc_index = reg / 2;
        int part = reg & 1;
        if (part == 0) {
            set_period_low(osc_index, value);
        } else {
            set_period_high(osc_index, value);
        }
    } else if (reg < 128 + (VOICES*OPERATORS)) { // 128 - 163
        int osc_index = reg - 128;
        set_volume_reg(osc_index, value);
    } else if (reg < 164 + VOICES) { // 164 - 173
        int osc_index = reg - 164;
        set_wave_type(osc_index, value);
    } else if (reg < 180 + (VOICES*OPERATORS)*2) { // 180 - 252
        int osc_index = reg - 180;
        if (osc_index & 1) set_env_sr(osc_index >> 1, value);
        else set_env_ad(osc_index >> 1, value);
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

static void set_volume_reg(int osc_index, UINT8 value) {
    osc *osc = &oscs[osc_index];
    osc->volume   = value & 0x3f;
    osc->envelope = value & 0x40;
    bool note_on_next  = value & 0x80;
    if (!osc->note_on && note_on_next) {
        osc->note_on = TRUE;
        env_start_stage(osc, ENV_ATTACK);
        debug_env = 0;
    } else if (osc->note_on && !note_on_next) {
        osc->note_on = FALSE;
        env_start_stage(osc, ENV_RELEASE);
    }
}

static void set_wave_type(int osc_index, UINT8 wave_type) {
    osc *osc = &oscs[osc_index];
    osc->wave_type = wave_type;
}

static void set_env_ad(int osc_index, UINT8 value) {
    osc *osc = &oscs[osc_index];
    osc->env_attack = (value & 0xF0) >> 4;
    osc->env_decay  = (value & 0x0F);
    env_start_stage(osc, ENV_ATTACK);
}

static void set_env_sr(int osc_index, UINT8 value) {
    osc *osc = &oscs[osc_index];
    osc->env_sustain = (value & 0xF0) >> 4;
    osc->env_release = (value & 0x0F);
    env_start_stage(osc, ENV_ATTACK);
}

static void env_start_stage(osc *voice, int stage) {
    voice->env_stage = stage;
    voice->env_phase = 0;
    if (stage == ENV_ATTACK) {
        voice->env_step  = att_step[voice->env_attack];
        voice->env_stop  = att_stop[voice->env_attack];
    } else if (stage == ENV_DECAY) {
        voice->env_step  = dec_step[voice->env_decay];
        voice->env_stop  = 0;
    } else if (stage == ENV_RELEASE) {
        voice->env_volume_release = voice->env_volume;
        voice->env_step  = rel_step[voice->env_release];
        voice->env_stop  = rel_stop[voice->env_release];
    }
}

static bool is_debug_env() {
    return debug_env >= MIN_DEBUG_ENV && debug_env <= MAX_DEBUG_ENV;
}

static void resolve_envelope_value(osc *voice) {
    if (!voice->envelope) {
        if (is_debug_env()) printf("no envelope ");
        voice->env_volume = 255;
        return;
    }

    if (voice->env_stage == ENV_ATTACK) {
        if (is_debug_env()) printf("attack envelope phase:%f stop:%d ", voice->env_phase, voice->env_stop);
        voice->env_volume = asc_table[(int)voice->env_phase];
        voice->env_phase += voice->env_step;
        if (voice->env_stop-- == 0) env_start_stage(voice, ENV_DECAY);
    } else if (voice->env_stage == ENV_DECAY) {
        if (is_debug_env()) printf("decay envelope phase:%f target sustain:%d ", voice->env_phase, (voice->env_sustain << 4 | 0x0f));
        voice->env_volume = des_table[(int)voice->env_phase];
        voice->env_phase += voice->env_step;
        if (voice->env_volume >> 4 == voice->env_sustain) voice->env_stage = ENV_SUSTAIN;
    } else if (voice->env_stage == ENV_SUSTAIN) {
        voice->env_volume = voice->env_sustain << 4 | 0x0f;
        if (is_debug_env()) printf("sustain envelope volume:%d ", voice->env_volume);
    } else if (voice->env_stage == ENV_RELEASE) {
        voice->env_volume = des_table[(int)voice->env_phase] * (float)(voice->env_volume_release / 255.0);
        if (is_debug_env()) printf("release envelope phase:%f stop:%d tab:%d", voice->env_phase, voice->env_stop, des_table[(int)voice->env_phase]);
        voice->env_phase += voice->env_step;
        if (voice->env_volume == 0) voice->env_stage = ENV_COMPLETE;
    }
}

void wopi_process(INT16 *buffer, UINT16 size) {
    for(int i=0; i<size; i+=2) {
        buffer[i+0] = 0;
        buffer[i+1] = 0;

        for(int v=0; v < 1; v++) {
            osc *voice = &oscs[v];

            int voice_value = 0;
            switch(voice->wave_type) {
                case WAVE_TYPE_SIN : voice_value = sin_table[(int)voice->phase]; break;
                case WAVE_TYPE_SAW : voice_value = (voice->phase - WAVE_HALF) * 32; break;
                case WAVE_TYPE_TRI : voice_value = voice->phase < WAVE_HALF ? (voice->phase*2 - WAVE_HALF) * 32 : (WAVE_SIZE - voice->phase*2) * 32 ; break;
                case WAVE_TYPE_SQR : voice_value = voice->phase < WAVE_HALF ? -32767 : 32767; break;
            }

            voice_value >>= 1;

            resolve_envelope_value(voice);
            UINT8  env_value = voice->env_volume;
            if (is_debug_env()) {
                printf("env_value[%d] = %d\n", debug_env, env_value);
            }
            debug_env++;

            //UINT16 voice_envelope = voice_value * 1; // (env_value / 255.0);
            //float  voice_final = voice_envelope * (voice->volume / 15.0) / 8.0f;

            int voice_envelope = voice_value * (env_value / 255.0);
            int voice_final = voice_envelope;

            buffer[i+0] += voice_final;
            buffer[i+1] += voice_final;

            voice->phase += voice->period;
            if (voice->phase >= WAVE_SIZE) voice->phase -= WAVE_SIZE;
        }
    }
}