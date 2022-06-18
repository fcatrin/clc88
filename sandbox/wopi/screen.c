#include <stdlib.h>
#include "emu.h"
#include "frontend.h"
#include "screen.h"

int screen_width;
int screen_height;
int screen_pitch;
int screen_size;

UINT8 *screen;

void screen_init() {
	screen_width  = SCREEN_XRES + SCREEN_XBORDER*2;
	screen_height = SCREEN_YRES + SCREEN_YBORDER*2;

	frontend_init_screen(screen_width, screen_height);

	screen_pitch = screen_width * 3;
    screen_size  = screen_pitch * screen_height;
	screen = malloc(screen_size);
}

void screen_update() {
	frontend_update_screen(screen);
}

void screen_clear() {
    memset(screen, 0, screen_size);
}

void screen_done() {
	free(screen);
}
