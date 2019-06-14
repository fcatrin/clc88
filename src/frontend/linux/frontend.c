#include <SDL.h>
#include <unistd.h>
#include "../../compy.h"
#include "../../emu.h"
#include "../../cpu.h"
#include "../../monitor.h"
#include "../frontend.h"

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

int  frontend_start_audio_stream(int stereo) {
	return 0;
}

void frontend_stop_audio_stream() {
}

int  frontend_update_audio_stream(INT16 *buffer) {
	return 0;
}

void frontend_sleep(int seconds) {
	sleep(seconds);
}

/* This is called from the emulator thread */
void frontend_update_screen(void *pixels) {
	while (buffer_next == buffer_post) {
		SDL_Delay(2);
	}
	memcpy(screen_buffers[buffer_next], pixels, screen_data_size);
	while (buffer_post>=0) {
		SDL_Delay(2);
	}
	buffer_post = buffer_next;
	buffer_next++;
	if (buffer_next == MAX_BUFFERS) buffer_next = 0;
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
	SDL_RenderPresent(renderer);

	SDL_DestroyTexture(texture);
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
		case SDL_KEYDOWN:
			switch( event.key.keysym.sym ){
				case SDLK_F1: monitor_enable(); break;
			}
		}
	}
}

int  frontend_init_screen(int width, int height) {
	window = SDL_CreateWindow("CLC88 Compy", 100, 100, width*2, height*2, SDL_WINDOW_SHOWN);
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
	if (SDL_Init(SDL_INIT_VIDEO) != 0){
		printf("SDL_Init Error: %s", SDL_GetError());
		return 1;
	}

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
}

int frontend_running() {
	return !closed;
}

static int runEmulatorThread(void *ptr){
    while (frontend_running()) {
    	compy_run();
    }
    return 0;
}

int main(int argc, char *argv[]) {
	if (frontend_init(argc, argv)) return 1;
	compy_init(argc, argv);

	emulator_thread = SDL_CreateThread(runEmulatorThread, "CompyThread", (void *)NULL);

	while (frontend_running()) {
		if (buffer_post>=0) {
			update_screen(screen_buffers[buffer_post]);
			buffer_post = -1;
		} else {
			SDL_Delay(2);
		}
		frontend_process_events();
	}

	frontend_done();
}

