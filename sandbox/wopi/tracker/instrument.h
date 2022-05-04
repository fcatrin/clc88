#ifndef __INSTRUMENT_H
#define __INSTRUMENT_H

instrument_t *instrument_new();
void          instrument_init(instrument_t *instrument, enum wave_type_t wave_type);
void          instrument_dump(instrument_t *instrument);

#endif