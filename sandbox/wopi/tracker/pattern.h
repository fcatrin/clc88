#ifndef __PATTERN_H
#define __PATTERN_H

pattern_t     *pattern_new();
void           pattern_add_row(pattern_t *pattern, song_t *song, char *line);
pattern_row_t *pattern_get_next_row(pattern_t *pattern);
void           pattern_dump(pattern_t *pattern);
void           pattern_dump_playing(pattern_t *pattern);
#endif