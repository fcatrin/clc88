#include <stdio.h>
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

int hexchar2int(char c) {
    if (c >= '0' && c <= '9') {
        return c - '0';
    }
    if (c >= 'A' && c <= 'F') {
        return c - 'A' + 10;
    }
    if (c >= 'a' && c <= 'f') {
        return c - 'a' + 10;
    }
    fprintf(stderr, "invalid hex char %c\n", c);
    return 0;
}

char int2hexchar(int n) {
    return n < 10 ? ('0' + n) : ('A' + n - 10);
}

int hex2int(char *hex) {
    return hexchar2int(hex[0])*16 + hexchar2int(hex[1]);
}

int load_parameter_int(const char *line, int index) {
    return atoi(load_parameter(line, index));
}

int load_parameter_hex(const char *line, int index) {
    char *hex = load_parameter(line, index);
    return hex2int(hex);
}

int load_parameter_hex_with_default(const char *line, int index, int default_value) {
    char *hex = load_parameter(line, index);
    if (strlen(hex) == 0) return default_value;
    return hex2int(hex);
}