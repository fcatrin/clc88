#ifndef _UTILS_H
#define _UTILS_H

void utils_load_xex(char *filename);
void utils_dump_mem(UINT16 offset, UINT16 size);

char *utils_str2lower(const char *src);
char *utils_str2upper( const char *src);

bool utils_starts_with(const char *s, const char *prefix);

char *utils_ltrim(const char *s);
char *utils_rtrim(const char *s);
char *utils_trim(const char *s);

char **utils_split(const char *s, unsigned *count);

#endif
