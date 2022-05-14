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

void instrument_init(instrument_t *instrument, opi_t *opis) {
    memcpy(&instrument->opis[0], opis, sizeof(opi_t) * MAX_OPERATORS);
}

void instrument_dump(instrument_t *instrument) {
    for(int i=0; i<MAX_OPERATORS; i++) {
        opi_t *opi = &instrument->opis[i];
        printf("opi[%d] wave_type %s adsr:%c%c%c%c multiplier:%c\n", i,
            tracker_get_wave_type_desc(opi->wave_type),
            int2hexchar(opi->adsr.attack),
            int2hexchar(opi->adsr.decay),
            int2hexchar(opi->adsr.sustain),
            int2hexchar(opi->adsr.release),
            int2hexchar(opi->multiplier)
            );
    }
}