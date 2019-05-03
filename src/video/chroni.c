#include <stdio.h>
#include "emu.h"
#include "cpu.h"
#include "cpuexec.h"
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
 *
 * Timings (using Atari 800 as a reference)
 * (https://www.atarimax.com/jindroush.atari.org/atanttim.html)
 *
 * Horizontal Timings
 * ------------------
 *
 * 0 start HSYNC
 * 14 end HSYNC
 * 32 end HBLANK - Start Wide
 * 34 Start Display
 * 44 Start Displayed wide
 * 48 Start Normal & start HSCROL
 * 64 Start Narrow
 * 128 Center
 * 192 End Narrow
 * 208 End WSYNC & end Normal
 * 220 End Displayed wide
 * 222 Start HBLANK - Inc VCOUNT - End Display
 * 224 End wide
 *
 * Atari 800 emulator display is
 * 0  - 32  : Never displayed
 * 32 - 44  : Black overscan
 * 44 - 48  : Border
 * 48 - 208 : Visible 160 clocks (320 pixels high res)
 * 208 - 212 : Border
 * 212 - 224 : Black overscan
 *
 *
 * Vertical Timings
 * ----------------
 *
 * 0 Reset VCOUNT
 * 8 Display start
 * 248 Display end (start VSYNC)
 * 274 Set VSYNC (PAL)
 * 278 reset VSYNC (PAL)
 *
 * Notes by DEBRO at http://atariage.com/forums/topic/24852-max-ntsc-resolution-of-atari-8-bit-and-2600/
 * PAL 312 (3-VSYNC/45-VBLANK/228-Kernel/36-overscan) and NTSC 262 (3-VSYNC/37-VBLANK/192-Kernel/30-overscan)
 *
 *
 *
 */

#define LOGTAG "CHRONI"

#define CPU_RUN(X) for(int nx=0; nx<X; nx++) CPU_GO(1)
#define CPU_SCANLINE() CPU_RUN(144-8);CPU_RESUME();CPU_RUN(8)
#define CPU_XPOS() if ((xpos++ & 3) == 0) CPU_GO(1)


#define VRAM_MAX 128*1024

UINT8 vram[VRAM_MAX];

#define PAGE_OFFSET 0x0400

static UINT16 scanline;
static UINT8  page;

static UINT16 dl;
static UINT16 lms = 0;
static UINT16 attribs = 0;
static UINT16 ypos, xpos;

static UINT8 colors[4];
static UINT16 palette;

static UINT16 charset;

// this is an RGB565 -> RGB888 conversion array for emulation only
static UINT8 rgb565[0x10000 * 3];
static UINT8 pixel_color_r;
static UINT8 pixel_color_g;
static UINT8 pixel_color_b;

#define STATUS_VBLANK 1
#define STATUS_HBLANK 2

static UINT8 status;

void chroni_vram_write(UINT16 index, UINT8 value) {
	LOGV(LOGTAG, "vram write %04X = %02X", index, value);
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
	LOGV(LOGTAG, "chroni reg write: %04X = %02X", index, value);
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
	case 8:
		CPU_HALT();
		break;
	case 16:
	case 17:
	case 18:
	case 19:
		colors[index - 16] = value;
		break;
	}
}

UINT8 chroni_register_read(UINT8 index) {
	switch(index) {
	case 7: return ypos >> 1;
	case 9: return status;
	}
	return 0;
}

static inline void set_pixel_color(UINT8 color) {
	UINT16 pixel_color_rgb565 = vram[palette + color*2 + 0] + (vram[palette + color*2 + 1] << 8);

	pixel_color_r = rgb565[pixel_color_rgb565*3 + 0];
	pixel_color_g = rgb565[pixel_color_rgb565*3 + 1];
	pixel_color_b = rgb565[pixel_color_rgb565*3 + 2];
}

static void do_scan_blank() {
	CPU_RUN(22);

	int start = scanline * screen_pitch;
	xpos = 0;
	for(int i=0; i<screen_width; i++) {
		set_pixel_color(colors[0]);
		screen[start + xpos*3 + 0] = pixel_color_r;
		screen[start + xpos*3 + 1] = pixel_color_g;
		screen[start + xpos*3 + 2] = pixel_color_b;

		CPU_XPOS();
	}
	CPU_RESUME();
	CPU_RUN(8);
}

static void do_scan_text(UINT8 line) {
	LOGV(LOGTAG, "do_scan_text line %d", line);
	CPU_RUN(22);

	int start = scanline * screen_pitch;
	xpos = 0;
	for(int i=0; i<SCREEN_XBORDER; i++) {
		set_pixel_color(colors[0]);
		screen[start + xpos*3 + 0] = pixel_color_r;
		screen[start + xpos*3 + 1] = pixel_color_g;
		screen[start + xpos*3 + 2] = pixel_color_b;
		CPU_XPOS();
	}

	UINT8 row;
	int offset = 0;
	for(int i=0; i<SCREEN_XRES; i++) {
		if (i % 8 == 0) {
			UINT8 c = vram[lms + offset];
			row = vram[charset + c*8 + line];
			offset++;
		}

		set_pixel_color(colors[row & 0x80 ? 2 : 1]);

		screen[start + xpos*3 + 0] = pixel_color_r;
		screen[start + xpos*3 + 1] = pixel_color_g;
		screen[start + xpos*3 + 2] = pixel_color_b;

		CPU_XPOS();
		row *= 2;
	}

	for(int i=0; i<SCREEN_XBORDER; i++) {
		set_pixel_color(colors[0]);
		screen[start + xpos*3 + 0] = pixel_color_r;
		screen[start + xpos*3 + 1] = pixel_color_g;
		screen[start + xpos*3 + 2] = pixel_color_b;
		CPU_XPOS();
	}
	CPU_RESUME();
	CPU_RUN(8);
}

static void do_scan_text_attribs(UINT8 line) {
	LOGV(LOGTAG, "do_scan_text_attribs line %d", line);
	CPU_RUN(22);

	int start = scanline * screen_pitch;
	xpos = 0;
	for(int i=0; i<SCREEN_XBORDER; i++) {
		set_pixel_color(colors[0]);
		screen[start + xpos*3 + 0] = pixel_color_r;
		screen[start + xpos*3 + 1] = pixel_color_g;
		screen[start + xpos*3 + 2] = pixel_color_b;
		CPU_XPOS();
	}

	UINT8 row;
	UINT8 foreground, background;
	int offset = 0;
	for(int i=0; i<SCREEN_XRES; i++) {
		if (i % 8 == 0) {
			UINT8 attrib = vram[attribs + offset];
			foreground = (attrib & 0xF0) >> 4;
			background = attrib & 0x0F;

			UINT8 c = vram[lms + offset];
			row = vram[charset + c*8 + line];
			offset++;
		}

		set_pixel_color(row & 0x80 ? foreground : background);

		screen[start + xpos*3 + 0] = pixel_color_r;
		screen[start + xpos*3 + 1] = pixel_color_g;
		screen[start + xpos*3 + 2] = pixel_color_b;

		CPU_XPOS();
		row *= 2;
	}

	for(int i=0; i<SCREEN_XBORDER; i++) {
		set_pixel_color(colors[0]);
		screen[start + xpos*3 + 0] = pixel_color_r;
		screen[start + xpos*3 + 1] = pixel_color_g;
		screen[start + xpos*3 + 2] = pixel_color_b;
		CPU_XPOS();
	}
	CPU_RESUME();
	CPU_RUN(8);
}


static void do_screen() {
	/* 0-7 scanlines are not displayed because of vblank
	 *
	 */
	for(ypos = 0; ypos <8; ypos++) {
		CPU_SCANLINE();
	}
	cpuexec_nmi(0);
	status &= !STATUS_VBLANK;
	LOGV(LOGTAG, "set status %02X", status);

	scanline = 0;

	UINT8 instruction;
	int dlpos = 0;
	while(scanline < screen_height) {
		instruction = vram[dl + dlpos];
		LOGV(LOGTAG, "DL instruction %04X = %02X", dl + dlpos, instruction);
		dlpos++;
		if ((instruction & 7) == 0) { // blank lines
			UINT8 lines = 1 + ((instruction & 0x70) >> 4);
			LOGV(LOGTAG, "do_scan_blank lines %d", lines);
			for(int line=0; line<lines; line++) {
				do_scan_blank();
				scanline++;
				ypos++;
				if (ypos == screen_height) return;
			}
		} else if ((instruction & 7) == 2) {
			if (instruction & 64) {
				lms = vram[dl + dlpos++];
				lms += 256*vram[dl + dlpos++];
			}
			LOGV(LOGTAG, "do_scan_text lms: %04X", lms);
			for(int line=0; line<8; line++) {
				do_scan_text(line);
				scanline++;
				ypos++;
				if (ypos == screen_height) return;
			}

			lms += 40;
		} else if ((instruction & 7) == 3) {
			if (instruction & 64) {
				lms = vram[dl + dlpos++];
				lms += 256*vram[dl + dlpos++];
				attribs = vram[dl + dlpos++];
				attribs += 256*vram[dl + dlpos++];
			}
			LOGV(LOGTAG, "do_scan_text_attrib lms: %04X attrib: %04X", lms, attribs);
			for(int line=0; line<8; line++) {
				do_scan_text_attribs(line);
				scanline++;
				ypos++;
				if (ypos == screen_height) return;
			}

			lms += 40;
			attribs += 40;
		} else if (instruction == 0x41) {
			break;
		}
	}
	for(;ypos <262; ypos++) {
		do_scan_blank();
		scanline++;
		ypos++;
		if (ypos == screen_height) return;
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

void chroni_init() {
	init_rgb565_table();
}

void chroni_run_frame() {
	do_screen();
	status |= STATUS_VBLANK;
	LOGV(LOGTAG, "set status %02X", status);
	cpuexec_nmi(1);
}
