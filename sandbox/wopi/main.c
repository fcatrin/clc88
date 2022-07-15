#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>
#include "emu.h"
#include "sound.h"
#include "screen.h"
#include "video.h"
#include "tracker/tracker.h"

#define LOGTAG "MAIN"
#ifdef TRACE_MAIN
#define TRACE
#endif
#include "trace.h"

unsigned long frame;

void main_init(int argc, char *argv[]) {
    frame = 0;

    tracker_init();
	screen_init();
	sound_init();
	video_init();

    char *test_file = "tracker/test/op4_alg_3.txt";
    if (argc > 1) {
        test_file = argv[1];
    }

	tracker_load(test_file);
}

unsigned long get_time() {
    struct timeval tv;
    gettimeofday(&tv,NULL);
    return 1000000 * tv.tv_sec + tv.tv_usec; // tine in microseconds
}

int skip_initial_frames = 60;

void main_run_frame() {
    video_start_frame();

    video_run_frame();

    int samples_per_frame = 44100.0 / 60;
    sound_process(samples_per_frame);

    if (skip_initial_frames > 0 ) {
        skip_initial_frames--;
    } else {
        // 1 frame = 1 tick. Simple enough for this test
        // https://modarchive.org/forums/index.php?topic=2709.0
        tracker_play();
    }

    video_end_frame();
}

void main_run() {
	main_run_frame();
	screen_update();
}

void main_done() {
	sound_done();
}
