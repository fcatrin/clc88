#ifndef __PATTERN_H
#define __PATTERN_H

pattern_t *pattern_new();
void       pattern_add_row(pattern_t *pattern, song_t *song, char *line);

#endif