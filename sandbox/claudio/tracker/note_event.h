#ifndef __NOTE_EVENT_H
#define __NOTE_EVENT_H

note_event_t *note_event_new();
void          note_event_init(note_event_t *event, char note, char accident, char octave);

#endif