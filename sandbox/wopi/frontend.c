#include <SDL.h>
#include <unistd.h>
#include <stdarg.h>
#include <time.h>
#include "emu.h"
#include "main.h"
#include "sound.h"

#define LOGTAG "FRONTEND"
#ifdef TRACE_FRONTEND
#define TRACE
#endif
#include "trace.h"

static SDL_Window *window;
static SDL_Renderer *renderer;
static int screen_width;
static int screen_height;
static int screen_data_size;
static int closed;

#define MAX_BUFFERS 3

static void *screen_buffers[MAX_BUFFERS];
static int buffer_next = 0;
static int buffer_post = -1;

static SDL_Thread *emulator_thread = NULL;
static SDL_AudioDeviceID dev;

#ifdef DUMP_AUDIO
FILE *sdebug;
#endif

int  frontend_start_audio_stream(int stereo) {
	SDL_AudioSpec want, have;

#ifdef DUMP_AUDIO
	sdebug = fopen("/home/fcatrin/audio.raw", "wb");
#endif

	SDL_memset(&want, 0, sizeof(want)); /* or SDL_zero(want) */
	want.freq = 44100;
	want.format = AUDIO_S16SYS;
	want.channels = stereo ? 2 : 1;
	want.samples = 4096;
	want.callback = NULL;

	dev = SDL_OpenAudioDevice(NULL, 0, &want, &have, 0);
	if (dev == 0) {
	    SDL_Log("Failed to open audio: %s", SDL_GetError());
	} else {
	    SDL_PauseAudioDevice(dev, 0); /* start audio playing. */
	}
	return 0;
}

void frontend_stop_audio_stream() {
#ifdef DUMP_AUDIO
	fclose(sdebug);
#endif
    SDL_CloseAudioDevice(dev);
}

void frontend_update_audio_stream() {
	UINT16 *buffer;
	unsigned size = 0;

	sound_fill_buffer(&buffer, &size);
	if (size == 0) return;

#ifdef DUMP_AUDIO
	fwrite(buffer, size*2, 1, sdebug);
#endif

	if (SDL_QueueAudio(dev, buffer, size*2)<0) {
		SDL_Log("Failed to open audio: %s", SDL_GetError());
	}
}

void frontend_sleep(int seconds) {
	sleep(seconds);
}

/* This is called from the emulator thread */
void frontend_update_screen(void *pixels) {
	while (buffer_next == buffer_post) {
		usleep(10);
	}
	memcpy(screen_buffers[buffer_next], pixels, screen_data_size);
	while (buffer_post>=0) {
		usleep(10);
	}
	buffer_post = buffer_next;
	buffer_next++;
	if (buffer_next == MAX_BUFFERS) buffer_next = 0;
}

void frontend_process_events() {
	SDL_Event event;
	while (SDL_PollEvent(&event)) {
		switch (event.type) {
		case SDL_WINDOWEVENT:
			if (event.window.event == SDL_WINDOWEVENT_CLOSE) {
				closed = 1;
			}
			break;
        }
	}
}

static void update_screen(void *pixels) {
	SDL_Surface *surface = SDL_CreateRGBSurfaceFrom(
			pixels, screen_width, screen_height, 24,
			screen_width*3, 0, 0, 0, 0);
	if (surface == NULL) {
		printf("SDL_CreateRGBSurfaceFrom Error: %s", SDL_GetError());
		return;
	}

	SDL_Texture *texture = SDL_CreateTextureFromSurface(renderer, surface);
	SDL_FreeSurface(surface);
	if (texture == NULL){
		printf("SDL_CreateTextureFromSurface Error: %s", SDL_GetError());
		return ;
	}

	SDL_RenderClear(renderer);
	SDL_RenderCopy(renderer, texture, NULL, NULL);
	buffer_post = -1;

	SDL_RenderPresent(renderer);
	SDL_DestroyTexture(texture);
}

int  frontend_init_screen(int width, int height) {
	window = SDL_CreateWindow("WOPI Test", 160, 20, width*2, height*4, SDL_WINDOW_SHOWN);
	if (window == NULL){
		printf("SDL_CreateWindow Error: %s", SDL_GetError());
		SDL_Quit();
		return 1;
	}

	renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
	if (renderer == NULL){
		SDL_DestroyWindow(window);
		printf("SDL_CreateRenderer Error: %s", SDL_GetError());
		SDL_Quit();
		return 1;
	}

    screen_width = width;
    screen_height = height;

    screen_data_size = width * 3 * height;

	for(int i=0; i<MAX_BUFFERS; i++) {
		screen_buffers[i] = malloc(screen_data_size);
	}

	return 0;
}

int frontend_init(int argc, char *argv[]) {
	closed = 0;
	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) != 0){
		printf("SDL_Init Error: %s", SDL_GetError());
		return 1;
	}

	frontend_start_audio_stream(1);

	return 0;
}

void frontend_shutdown() {
	closed = TRUE;
}

void frontend_done() {
	SDL_DestroyRenderer(renderer);
	SDL_DestroyWindow(window);
	SDL_Quit();

	for(int i=0; i<MAX_BUFFERS; i++) {
		free(screen_buffers[i]);
	}

	frontend_stop_audio_stream();
}

int frontend_running() {
	return !closed;
}

static int runEmulatorThread(void *ptr){
    while (frontend_running()) {
    	main_run();
    }
    return 0;
}

void frontend_trace_msg(char *tag, ...) {
	va_list args;
	va_start(args, tag);
	char *format = va_arg(args, char *);

	fprintf(stdout, "[%s] ", tag);

#ifdef TRACE_TIME
	char buffer[26];
	time_t timer;
	struct tm* tm_info;
	timer = time(NULL);
	tm_info = localtime(&timer);
	strftime(buffer, 26, "%Y-%m-%d %H:%M:%S", tm_info);
	fprintf(stdout, "[%s] ", buffer);
#endif
	vfprintf(stdout, format, args);
	fprintf(stdout, "\n");
	va_end(args);

	fflush(stdout);
}

void frontend_trace_err(char *tag, ...) {

	va_list args;
	va_start(args, tag);
	char *format = va_arg(args, char *);

	fprintf(stderr, "[%s] ", tag);
	vfprintf(stderr, format, args);
	fprintf(stderr, "\n");
	va_end(args);

	fflush(stderr);
}

int main(int argc, char *argv[]) {
    LOGV(LOGTAG, "init");
	if (frontend_init(argc, argv)) return 1;
	main_init(argc, argv);

	emulator_thread = SDL_CreateThread(runEmulatorThread, "EmuThread", (void *)NULL);

    LOGV(LOGTAG, "main loop start");
	while (frontend_running()) {
        LOGV(LOGTAG, "main loop run");
		if (buffer_post>=0) {
            LOGV(LOGTAG, "main loop update audio stream");
            frontend_update_audio_stream();
            update_screen(screen_buffers[buffer_post]);
		} else {
			usleep(10);
		}
		LOGV(LOGTAG, "main loop process events");
		frontend_process_events();
	}
    LOGV(LOGTAG, "main loop end");
	frontend_done();
	return 0;
}

