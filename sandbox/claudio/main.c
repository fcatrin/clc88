#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "emu.h"
#include "sound.h"
#include "screen.h"

#define LOGTAG "MAIN"
#ifdef TRACE_MAIN
#define TRACE
#endif
#include "trace.h"

void main_init(int argc, char *argv[]) {
	screen_init();
	sound_init();
}

void main_run_frame() {
    int samples_per_frame = 44100.0 / 60;
    sound_process(samples_per_frame);
}

void main_run() {
	main_run_frame();
	screen_update();
}

void main_done() {
	sound_done();
}
