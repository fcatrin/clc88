#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "emu.h"
#include "utils.h"
#include "sound.h"

#define LOGTAG "MAIN"
#ifdef TRACE_MAIN
#define TRACE
#endif
#include "trace.h"

void main_init(int argc, char *argv[]) {
	sound_init();
}

void main_run_frame() {
    sound_process(samples_per_frame);
}

void main_run() {
	main_run_frame();
}

void main_done() {
	sound_done();
}
