#ifndef _SCREEN_H
#define _SCREEN_H

#define SCREEN_XRES 640
#define SCREEN_YRES 240

#define SCREEN_XBORDER 48
#define SCREEN_YBORDER 4

extern int screen_width;
extern int screen_height;
extern int screen_pitch;

extern UINT8 *screen;

void screen_init();
void screen_update();
void screen_done();

#endif
