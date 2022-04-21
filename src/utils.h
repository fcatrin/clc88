#ifndef _UTILS_H
#define _UTILS_H

#include <sys/stat.h>

void utils_load_xex(char *filename);
void utils_load_bin(char *filename, UINT16 addr);
void utils_dump_mem(UINT16 offset, UINT16 size);

char *utils_str2lower(const char *src);
char *utils_str2upper( const char *src);

bool utils_starts_with(const char *s, const char *prefix);

char *utils_ltrim(const char *s);
char *utils_rtrim(const char *s);
char *utils_trim(const char *s);

char **utils_split(const char *s, unsigned *count);

char *utils_format_date(time_t time);
char *utils_format_time(time_t time);


#endif
