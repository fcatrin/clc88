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

static unsigned long t0;
void sync_start() {
    if (frame == 0) t0 = get_time();
    frame++;
}

// this is awful but this test doesn't need anything more advanced
void sync_end() {
    unsigned long now = get_time() - t0;
    unsigned long time_target = frame * (1000000.0 / 60);
    long delta = time_target - now - 2000; // just make a bit of room to avoid clicks
    // printf("target:%lu now:%lu\n", time_target, now);
    if (delta > 0) {
        // printf("usleep %lu\n", delta);
        usleep(delta);
    }
}

void main_run_frame() {
    video_start_frame();
    sync_start();

    video_run_frame();

    int samples_per_frame = 44100.0 / 60;
    sound_process(samples_per_frame);

    // 1 frame = 1 tick. Simple enough for this test
    // https://modarchive.org/forums/index.php?topic=2709.0
    tracker_play();

    sync_end();
    video_end_frame();
}

void main_run() {
	main_run_frame();
	screen_update();
}

void main_done() {
	sound_done();
}
