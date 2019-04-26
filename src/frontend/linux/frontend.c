#include <SDL.h>
#include <unistd.h>
#include "../../emu.h"
#include "../frontend.h"

static SDL_Window *window;
static SDL_Renderer *renderer;
static int screen_width;
static int screen_height;
static int closed;

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

void frontend_update_screen(void *pixels) {
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

void frontend_done() {
	SDL_DestroyRenderer(renderer);
	SDL_DestroyWindow(window);
	SDL_Quit();
}

int frontend_running() {
	return !closed;
}

