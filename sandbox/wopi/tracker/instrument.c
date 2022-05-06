#include <malloc.h>
#include <string.h>
#include "../emu.h"
#include "tracker.h"
#include "tracker_utils.h"
#include "instrument.h"

instrument_t *instrument_new() {
    instrument_t *instrument = (instrument_t *)malloc(sizeof(instrument_t));
    return instrument;
}

void instrument_init(instrument_t *instrument, enum wave_type_t wave_type, adsr_t *adsr) {
    instrument->wave_type = wave_type;
    memcpy(&instrument->adsr[0], adsr, sizeof(adsr_t) * MAX_OPERATORS);
}

void instrument_dump(instrument_t *instrument) {
    printf("wave_type %s adsr:%c%c%c%c\n",
        tracker_get_wave_type_desc(instrument->wave_type),
        int2hexchar(instrument->adsr[0].attack),
        int2hexchar(instrument->adsr[0].decay),
        int2hexchar(instrument->adsr[0].sustain),
        int2hexchar(instrument->adsr[0].release)
        );
}