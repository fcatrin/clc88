#include <malloc.h>
#include "../emu.h"
#include "tracker.h"
#include "pattern.h"

pattern_t *pattern_new() {
    pattern_t *pattern = (pattern_t *)malloc(sizeof(pattern_t));
    // pattern->rows = null;
    return pattern;
}

void pattern_add_row(pattern_t *pattern, char *line) {

}