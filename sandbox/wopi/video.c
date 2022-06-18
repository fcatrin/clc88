#include "stdio.h"
#include "emu.h"
#include "screen.h"

#define POINT(x, y) ((x) * 3 + (y) * screen_pitch)
#define RGB(r, g, b) ((r) + ((g) << 8) + ((b) << 16))

UINT8 pixel_color_r;
UINT8 pixel_color_g;
UINT8 pixel_color_b;

UINT32 palette[256];

static void set_pixel_color(UINT8 dot_color) {
    UINT32 palette_entry = palette[dot_color];
    pixel_color_r = (palette_entry         & 0xff);
    pixel_color_g = ((palette_entry >> 8)  & 0xff);
    pixel_color_b = ((palette_entry >> 16) & 0xff);
}

static void inline put_pixel(int offset) {
	screen[offset + 0] = pixel_color_r;
	screen[offset + 1] = pixel_color_g;
	screen[offset + 2] = pixel_color_b;
	printf("put pixel offset:%d %02x %02x %02x\n", offset, pixel_color_r, pixel_color_g, pixel_color_b);
}

void video_init(){
    palette[0] = 0;
    palette[1] = RGB(100, 100, 100);
}

void video_done(){}

void video_start_frame() {}
void video_run_frame(){
    int x = 200;
    int y = 100;
    int offset = POINT(x, y);
    set_pixel_color(1);
    put_pixel(offset);
}
void video_end_frame() {}
