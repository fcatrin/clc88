#include <stdlib.h>
#include "../emu.h"
#include "../frontend/frontend.h"
#include "screen.h"

int screen_width;
int screen_height;
int screen_pitch;

UINT8 *screen;

void screen_init() {
	screen_width  = SCREEN_XRES + SCREEN_XBORDER*2;
	screen_height = SCREEN_YRES + SCREEN_YBORDER*2;

	frontend_init_screen(screen_width, screen_height);

	screen_pitch = screen_width * 3;

	screen = malloc(screen_pitch * screen_height);

	screen[screen_pitch * 20 + 80*3 + 0] = 0xFF;
	screen[screen_pitch * 20 + 80*3 + 1] = 0xFF;
	screen[screen_pitch * 20 + 80*3 + 2] = 0xFF;
}

void screen_update() {
	frontend_update_screen(screen);
}

void screen_done() {
	free(screen);
}
