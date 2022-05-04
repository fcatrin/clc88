#include <malloc.h>
#include "../emu.h"
#include "tracker.h"
#include "instrument.h"

instrument_t *instrument_new() {
    instrument_t *instrument = (instrument_t *)malloc(sizeof(instrument_t));
    return instrument;
}

void instrument_init(instrument_t *instrument, enum wave_type_t wave_type) {
    instrument->wave_type = wave_type;
}

void instrument_dump(instrument_t *instrument) {
    printf("wave_type %s\n", tracker_get_wave_type_desc(instrument->wave_type));
}