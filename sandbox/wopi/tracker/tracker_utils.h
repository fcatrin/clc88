#ifndef __TRACKER_UTILS
#define __TRACKER_UTILS

char *ltrim(char *s);
char *rtrim(char *s);
char *trim(char *s);
bool starts_with(const char *str, const char *pre);

char *load_parameter    (const char *line, int index);
int   load_parameter_int(const char *line, int index);

#endif