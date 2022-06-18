#include "stdio.h"
#include "emu.h"
#include "sound.h"
#include "screen.h"

#define POINT(x, y) ((x) * 3 + (y) * screen_pitch)
#define RGB(r, g, b) ((r) + ((g) << 8) + ((b) << 16))

UINT8 pixel_color_r;
UINT8 pixel_color_g;
UINT8 pixel_color_b;

UINT32 palette[256];

#define SAMPLE_RES 5
#define MONITOR_BUFFER_SIZE 640*SAMPLE_RES
INT16 *monitor_buffer;

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
	// printf("put pixel offset:%d %02x %02x %02x\n", offset, pixel_color_r, pixel_color_g, pixel_color_b);
}

void video_init(){
    palette[0] = 0;
    palette[1] = RGB(200, 200, 200);

    monitor_buffer = sound_get_monitor_buffer(MONITOR_BUFFER_SIZE);
}

void video_done(){}

void video_start_frame() {
    screen_clear();
}

void video_run_frame(){
    int center_y = 120;
    int last_y   = center_y;
    set_pixel_color(1);
    for(int x=0; x<640; x++) {
        int sample = monitor_buffer[x*SAMPLE_RES] * 200.0f / 32767;
        int sample_y = center_y + sample;
        int dy = sample_y > last_y ? 1 : -1;
        for(int y = last_y; y!=sample_y; y += dy) {
            int offset = POINT(x + SCREEN_XBORDER, y);
            put_pixel(offset);
        }
        int offset = POINT(x + SCREEN_XBORDER, sample_y);
        put_pixel(offset);
        last_y = sample_y;
    }
}
void video_end_frame() {}
