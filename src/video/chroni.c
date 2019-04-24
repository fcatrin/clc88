#include <stdio.h>
#include "../emu.h"
#include "screen.h"
#include "chroni.h"
#include "trace.h"

/*
 * This is the main Video Processor Unit
 *
 * The name comes from "Chroni, partners in time" (with the CPU)
 * Suggested by Stuart Law from "Cronie, partners in crime" a popular english saying
 *
 *
 * There is no need for a memory map
 * This is a recommended map
 *
 * 00000 -
 * 1F000 - 1F3FF : Charset
 * 1F800 - 1FFFF : Main Color palettes (256 * 2bytes RGB565)
 *
 * Registers:
 * 00 : WORD Display List pointer
 * 02 : WORD Charset pointer
 * 04 : WORD Palette pointer
 * 05 : BYTE 16KB page mapped on system memory. 1KB granularity
 * 10 : BYTE Border color
 * 11 : BYTE Simple Text mode background
 * 12 : BYTE Simple Text mode foreround
 *
 * The pallete is a 256 16 bit RGB565 colors array (512 bytes)
 *
 * A color is 1 byte index over the palette So color 0x23 will use
 * the RGB565 built from palette[0x23 * 2] and the next byte
 *
 * The Simple text mode is a 40 chars wide text mode
 * with single foreground / background colors.
 * This is similar to ANTIC 2 mode
 *
 */


#define VRAM_MAX 128*1024

UINT8 vram[VRAM_MAX];

#define PAGE_OFFSET 0x0400

static UINT16 scanline;
static UINT8  page;

static UINT16 dl;
static UINT16 lms = 0;

static UINT8 colors[4];
static UINT16 palette;

static UINT16 charset;

// this is an RGB565 -> RGB888 conversion array for emulation only
static UINT8 rgb565[0x10000 * 3];
static UINT8 pixel_color_r;
static UINT8 pixel_color_g;
static UINT8 pixel_color_b;

void chroni_vram_write(UINT16 index, UINT8 value) {
	LOGV("vram write %04X = %02X", index, value);
	vram[page * PAGE_OFFSET + index] = value;
}

UINT8 chroni_vram_read(UINT16 index) {
	return vram[page * PAGE_OFFSET + index];
}

static void reg_low(UINT16 *reg, UINT8 value) {
	*reg = (*reg & 0xFF00) | value;
}

static void reg_high(UINT16 *reg, UINT8 value) {
	*reg = (*reg & 0x00FF) | (value << 8);
}

void chroni_register_write(UINT8 index, UINT8 value) {
	LOGV("chroni reg write: %04X = %02X", index, value);
	switch (index) {
	case 0:
		reg_low(&dl, value);
		break;
	case 1:
		reg_high(&dl, value);
		break;
	case 2:
		reg_low(&charset, value);
		break;
	case 3:
		reg_high(&charset, value);
		break;
	case 4:
		reg_low(&palette, value);
		break;
	case 5:
		reg_high(&palette, value);
		break;
	case 6:
		page = value & 0x7F;  // page offset in KB
		break;

	case 16:
	case 17:
	case 18:
	case 19:
		colors[index - 16] = value;
		break;
	}
}

static inline void set_pixel_color(UINT8 color) {
	UINT16 pixel_color_rgb565 = vram[palette + color*2 + 0] + (vram[palette + color*2 + 1] << 8);

	pixel_color_r = rgb565[pixel_color_rgb565*3 + 0];
	pixel_color_g = rgb565[pixel_color_rgb565*3 + 1];
	pixel_color_b = rgb565[pixel_color_rgb565*3 + 2];
}

static void do_scan_blank() {
	set_pixel_color(colors[0]);

	int start = scanline * screen_pitch;
	for(int i=0; i<screen_width; i++) {
		screen[start + i*3 + 0] = pixel_color_r;
		screen[start + i*3 + 1] = pixel_color_g;
		screen[start + i*3 + 2] = pixel_color_b;
	}
}

static void do_scan_text(UINT8 line) {
	LOGV("do_scan_text line %d", line);
	set_pixel_color(colors[0]);

	int start = scanline * screen_pitch;
	int x = 0;
	for(int i=0; i<SCREEN_XBORDER; i++) {
		screen[start + x*3 + 0] = pixel_color_r;
		screen[start + x*3 + 1] = pixel_color_g;
		screen[start + x*3 + 2] = pixel_color_b;
		x++;
	}

	UINT8 row;
	int offset = 0;
	for(int i=0; i<SCREEN_XRES; i++) {
		if (i % 8 == 0) {
			UINT8 c = vram[lms + offset];
			row = vram[charset + c*8 + line];
			LOGV("read char %04X = %02X row %04X = %02X", lms + offset, c,
					charset + c*8 + line, row);
			offset++;
		}

		set_pixel_color(colors[row & 0x80 ? 2 : 1]);

		screen[start + x*3 + 0] = pixel_color_r;
		screen[start + x*3 + 1] = pixel_color_g;
		screen[start + x*3 + 2] = pixel_color_b;

		x++;
		row *= 2;
	}

	set_pixel_color(colors[0]);
	for(int i=0; i<SCREEN_XBORDER; i++) {
		screen[start + x*3 + 0] = pixel_color_r;
		screen[start + x*3 + 1] = pixel_color_g;
		screen[start + x*3 + 2] = pixel_color_b;
		x++;
	}

}

static void do_screen() {
	scanline = 0;

	UINT8 instruction;
	int dlpos = 0;
	while(scanline < screen_height) {
		instruction = vram[dl + dlpos];
		LOGV("DL instruction %04X = %02X", dl + dlpos, instruction);
		dlpos++;
		if ((instruction & 7) == 0) { // blank lines
			UINT8 lines = 1 + ((instruction & 0x70) >> 4);
			LOGV("do_scan_blank lines %d", lines);
			for(int line=0; line<lines; line++) {
				do_scan_blank();
				scanline++;
				if (scanline == screen_height) return;
			}
		} else if ((instruction & 7) == 2) {
			if (instruction & 64) {
				lms = vram[dl + dlpos++];
				lms += 256*vram[dl + dlpos++];
			}
			LOGV("do_scan_text lms: %04X", lms);
			for(int line=0; line<8; line++) {
				do_scan_text(line);
				scanline++;
				if (scanline == screen_height) return;
			}

			lms += 40;
		} else if (instruction == 0x41) {
			break;
		}
	}

}

static void init_rgb565_table() {
	for(int c=0; c<0x10000; c++) {
		UINT8 r = ((c & 0xF800) >> 11) * (256 / 32);
		UINT8 g = ((c & 0X07E0) >> 5)  * (256 / 64);
		UINT8 b = (c & 0X001F) * (256 / 32);

		rgb565[c*3 + 0] = b;
		rgb565[c*3 + 1] = g;
		rgb565[c*3 + 2] = r;
	}
}

void chroni_run() {
	init_rgb565_table();
	do_screen();
}
