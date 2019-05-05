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
 * 06 : BYTE 16KB page mapped on system memory. 1KB granularity
 * 07 : BYTE VCount (vertical line count / 2)
 * 08 : BYTE WSYNC. Any write will halt the CPU until next HBLANK
 * 09 : BYTE Status:
 *      ?????XXX
 *             |--- VBLANK active (read only)
 *            |---- HBLANK active (read only)
 *           |----- Interrupts enabled
 * 0A : WORD Sprites base address
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
 * Sprites
 * -------
 * - 32 sprites
 * - 16x16 pixels
 * - 15 colors from the global 256 color palette
 * - 0 is transparent
 * - X range: from 0 to 384.
 *   24 is start of left border, 32 is start of display screen
 *   352 is start of right border
 *   340 is out of the visible screen
 * - Y range: from 0 to 262
 *   16 is the first scan line
 *   246 is out of the visible screen
 *
 * Sprite memory
 * - 64 bytes sprite pointer. 2 bytes per sprite. Location is pointer*2
 * - 64 bytes x position. 2 bytes per sprite
 * - 64 bytes y position. 2 bytes per sprite
 * - 64 attribute bytes. 2 byte per sprite:
 *   xxxxxxxxXXXXXXXX
 *               ||||---- color palette index
 *              |--- visible
 *   |||||||||||-------- reserved for future use (scaling? rotating?)
 * - 32*16 bytes: 32 palettes of 16 indexed colors
 *   Each index point to the global palette entries
 *
 * Sprite memory map
 * 0000 Sprite pointers
 * 0040 X position
 * 0080 Y position
 * 00C0 attributes
 * 0100 color palette
 * 01FF end of sprite memory
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
static UINT16 sprites;

// this is an RGB565 -> RGB888 conversion array for emulation only
static UINT8 rgb565[0x10000 * 3];
static UINT8 pixel_color_r;
static UINT8 pixel_color_g;
static UINT8 pixel_color_b;

#define STATUS_VBLANK 1
#define STATUS_HBLANK 2
#define STATUS_INTEN  4

static UINT8 status;
static UINT8 post_dli = 0;

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
	case 9:
		status = (status & 0x3) | (value & 0xFC);
		break;
	case 0xa:
		reg_low(&sprites, value);
		break;
	case 0xb:
		reg_high(&sprites, value);
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

static void do_scan_start() {
	status |= STATUS_HBLANK;
	if (post_dli && (status & STATUS_INTEN)) {
		LOGV(LOGTAG, "do_scan_start fire DLI");
		cpuexec_nmi(1);
	}
	post_dli = 0;

	CPU_RUN(22);
	status &= (255 - STATUS_HBLANK);
	cpuexec_nmi(0);
}

static void do_scan_end() {
	CPU_RESUME();
	CPU_RUN(8);
}

#define SPRITE_ATTR_ENABLED 0x10

#define SPRITES_MAX   32
#define SPRITES_X     (SPRITES_MAX * 2)
#define SPRITES_Y     (SPRITES_MAX * 2 + SPRITES_X)
#define SPRITES_ATTR  (SPRITES_MAX * 2 + SPRITES_Y)
#define SPRITES_COLOR (SPRITES_MAX * 2 + SPRITES_ATTR)


static void do_scan_blank() {
	do_scan_start();

	int start = scanline * screen_pitch;
	xpos = 0;
	for(int i=0; i<screen_width; i++) {
		UINT8 dot_color   = 0;
		UINT8 sprite_data = 0;
		for(int s=SPRITES_MAX-1; s>=0; s--) {
			UINT16 sprite_attrib = vram[sprites + SPRITES_ATTR + s*2];
			if ((sprite_attrib & SPRITE_ATTR_ENABLED) == 0) continue;

			int sprite_y =
				   vram[sprites + SPRITES_Y + s*2]
				+ (vram[sprites + SPRITES_Y + s*2+1] << 8) - 16;

			int sprite_scanline = scanline - sprite_y;
			if (sprite_scanline< 0 || sprite_scanline >=16) continue;

			int sprite_x =
				   vram[sprites + SPRITES_X + s*2]
				+ (vram[sprites + SPRITES_X + s*2+1] << 8) - 24;
			int sprite_pixel_x = xpos - sprite_x;
			if (sprite_pixel_x < 0 || sprite_pixel_x >=16) continue;

			int sprite_pointer =
					(vram[sprites + s*2] +
					(vram[sprites + s*2+1] << 8)) << 1;

			sprite_data = vram[sprite_pointer
					+ (sprite_scanline << 3)
					+ (sprite_pixel_x  >> 1)];
			sprite_data = (sprite_pixel_x & 1) == 0 ?
					sprite_data >> 4 :
					sprite_data & 0xF;
			if (sprite_data == 0) continue;

			int sprite_palette = sprite_attrib & 0x0F;

			dot_color = vram[sprites + SPRITES_COLOR + sprite_palette*16 + sprite_data];
			break;
		}

		if (sprite_data == 0) dot_color = colors[0];
		set_pixel_color(dot_color);
		screen[start + xpos*3 + 0] = pixel_color_r;
		screen[start + xpos*3 + 1] = pixel_color_g;
		screen[start + xpos*3 + 2] = pixel_color_b;

		CPU_XPOS();
	}
	do_scan_end();
}

static void do_scan_text(UINT8 line) {
	LOGV(LOGTAG, "do_scan_text line %d", line);
	do_scan_start();

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
	do_scan_end();
}

static void do_scan_text_attribs(UINT8 line) {
	LOGV(LOGTAG, "do_scan_text_attribs line %d", line);
	do_scan_start();

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
	do_scan_end();
}

static void do_screen() {
	/* 0-7 scanlines are not displayed because of vblank
	 *
	 */
	for(ypos = 0; ypos <8; ypos++) {
		CPU_SCANLINE();
	}
	cpuexec_nmi(0);
	status &= (255 - STATUS_VBLANK);
	LOGV(LOGTAG, "set status %02X", status);

	scanline = 0;

	UINT8 instruction;
	int dlpos = 0;
	while(ypos < screen_height) {
		instruction = vram[dl + dlpos];
		int scan_post_dli = instruction & 0x80;
		LOGV(LOGTAG, "DL instruction %04X = %02X", dl + dlpos, instruction);
		dlpos++;
		if ((instruction & 7) == 0) { // blank lines
			UINT8 lines = 1 + ((instruction & 0x70) >> 4);
			LOGV(LOGTAG, "do_scan_blank lines %d", lines);
			for(int line=0; line<lines; line++) {
				if (line == lines - 1) post_dli = scan_post_dli;
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
			int lines = 8;
			for(int line=0; line<lines; line++) {
				if (line == lines - 1) post_dli = scan_post_dli;
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
			int lines = 8;
			for(int line=0; line<8; line++) {
				if (line == lines - 1) post_dli = scan_post_dli;
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
	for(;scanline <screen_height; scanline++) {
		do_scan_blank();
		ypos++;
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
	if (status & STATUS_INTEN) cpuexec_nmi(1);
}
