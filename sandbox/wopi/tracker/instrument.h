#ifndef __INSTRUMENT_H
#define __INSTRUMENT_H

instrument_t *instrument_new();
void instrument_init(instrument_t *instrument, UINT8 volume, UINT8 algorithm, opi_t *opis);
void instrument_dump(instrument_t *instrument);

#endif