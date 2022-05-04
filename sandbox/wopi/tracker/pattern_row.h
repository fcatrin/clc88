#ifndef __PATTERN_ROW_H
#define __PATTERN_ROW_H

pattern_row_t *pattern_row_new(int channels);
void           pattern_row_load(pattern_row_t *pattern_row, char *line);
void           pattern_row_dump(pattern_row_t *pattern_row);

#endif