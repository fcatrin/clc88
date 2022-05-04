#ifndef __SONG_H
#define __SONG_H

song_t        *song_new();
void           song_add_pattern(song_t *song, pattern_t *pattern);
pattern_row_t *song_get_row(song_t *song);

#endif