#ifndef __NOTE_EVENT_H
#define __NOTE_EVENT_H

note_event_t *note_event_new();
void          note_event_init(note_event_t *event, int instrument, char note, char accident, char octave);
void          note_event_dump(note_event_t *event);

#endif