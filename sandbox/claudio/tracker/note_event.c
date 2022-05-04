#include <malloc.h>
#include "../emu.h"
#include "tracker.h"
#include "note_event.h"

int note_table[] = {0, 2, 3, 5, 7, 8, 10};

note_event_t *note_event_new() {
    note_event_t *event = (note_event_t *)malloc(sizeof(note_event_t));
    return event;
}

void note_event_init(note_event_t *event, char note, char accident, char octave) {
    event->note = NO_NOTE;
    if (note == '+') {
        event->sustain = TRUE;
    } else if (note >= 'A' && note <= 'G') {
        int note_index = note_table[note - 'A'];
        if (accident == '#') note_index ++;

        int note_octave = 0;
        if (octave >= '0' && octave <= '9') {
            note_octave = octave - '0';
        }
        event->note = note_octave * 12 + note_index;
        event->sustain = TRUE;
    } else {
        event->sustain = FALSE;
    }
}