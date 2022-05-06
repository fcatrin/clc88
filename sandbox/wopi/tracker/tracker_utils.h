#ifndef __TRACKER_UTILS
#define __TRACKER_UTILS

char *ltrim(char *s);
char *rtrim(char *s);
char *trim(char *s);
bool starts_with(const char *str, const char *pre);

char *load_parameter    (const char *line, int index);
int   load_parameter_int(const char *line, int index);
int   load_parameter_hex(const char *line, int index);

int hex2int(char *hex);
int hexchar2int(char c);
char int2hexchar(int n);

#endif