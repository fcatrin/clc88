#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "../emu.h"

char *ltrim(char *s) {
    while(isspace(*s)) s++;
    return s;
}

char *rtrim(char *s) {
    char* back = s + strlen(s);
    while(isspace(*--back));
    *(back+1) = '\0';
    return s;
}

char *trim(char *s) {
    return rtrim(ltrim(s));
}

bool starts_with(const char *str, const char *pre) {
    return strncmp(pre, str, strlen(pre)) == 0;
}

char *load_parameter(const char *line, int index) {
    static char buffer[200];

    strcpy(buffer, "");

    int i = 0;
    do {
        int j = 0;
        for(; i<strlen(line); i++) {
            if (isspace(line[i])) break;
            buffer[j++] = line[i];
        }
        buffer[j] = 0;

        for(; i<strlen(line); i++) {
            if (!isspace(line[i])) break;
        }

        index--;
    } while (index > 0);
    return buffer;
}

int load_parameter_int(const char *line, int index) {
    return atoi(load_parameter(line, index));
}