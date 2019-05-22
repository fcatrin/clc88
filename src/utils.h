#ifndef _UTILS_H
#define _UTILS_H

void utils_load_xex(char *filename);
void utils_dump_mem(UINT16 offset, UINT16 size);

char *utils_str2lower(const char *src);
char *utils_str2upper( const char *src);

#endif
