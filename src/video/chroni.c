#include <stdio.h>
#include "emu.h"
#include "cpu.h"
#include "cpuexec.h"
#include "screen.h"
#include "chroni.h"

#define LOGTAG "CHRONI"
#ifdef TRACE_CHRONI
#define TRACE
#endif
#include "trace.h"


#define CPU_RUN(X) for(int nx=0; nx<X; nx++) CPU_GO(1)
#define CPU_SCANLINE() CPU_RUN(144-8);CPU_RESUME();CPU_RUN(8)
#define CPU_XPOS() if ((xpos++ & 3) == 0) CPU_GO(1)

#define VRAM_WORD(addr) (WORD(VRAM_DATA(addr), VRAM_DATA(addr+1)))
#define VRAM_PTR(addr) (VRAM_WORD(addr) << 1)
#define VRAM_DATA(addr) (vram[(addr) & 0x1FFFF])

#define VRAM_MAX 128*1024

UINT8 vram[VRAM_MAX];

#define PAGE_SIZE       0x4000
#define PAGE_SHIFT      14
#define PAGE_SHIFT_HIGH (PAGE_SHIFT-8)
#define PAGE_BASE(x)    (x << PAGE_SHIFT)

static UINT16 scanline;
static UINT8  page;

static UINT32 dl;
static UINT16 lms = 0;
static UINT16 attribs = 0;
static UINT16 ypos, xpos;

static UINT8  border_color = 0;
static UINT32 palette;
static UINT32 subpals;

static UINT32 charset;
static UINT32 sprites;

static UINT32 tileset_small;
static UINT32 tileset_big;

// this is an RGB565 -> RGB888 conversion array for emulation only
static UINT8 rgb565[0x10000 * 3];
static UINT8 pixel_color_r;
static UINT8 pixel_color_g;
static UINT8 pixel_color_b;

#define STATUS_VBLANK         0x01
#define STATUS_HBLANK         0x02
#define STATUS_ENABLE_INTS    0x04
#define STATUS_ENABLE_SPRITES 0x08
#define STATUS_ENABLE_CHRONI  0x10


static UINT8 status;
static UINT8 post_dli = 0;

void chroni_reset() {
	status = 0;
	dl = 0;
	charset = 0;
	sprites = 0;
	palette = 0;
	tileset_small = 0;
}

void chroni_vram_write(UINT16 index, UINT8 value) {
	LOGV(LOGTAG, "vram write %04X = %02X", index, value);
	VRAM_DATA(PAGE_BASE(page) + index) = value;
}

UINT8 chroni_vram_read(UINT16 index) {
	return VRAM_DATA(PAGE_BASE(page) + index);
}

static void reg_addr_low(UINT32 *reg, UINT8 value) {
	*reg = (*reg & 0xFFFE00) | (value << 1);
}

static void reg_addr_high(UINT32 *reg, UINT8 value) {
	*reg = (*reg & 0x001FF) | (value << 9);
}

void chroni_register_write(UINT8 index, UINT8 value) {
	LOGV(LOGTAG, "chroni reg write: 0x%04X = 0x%02X", index, value);
	switch (index) {
	case 0:
		reg_addr_low(&dl, value);
		break;
	case 1:
		reg_addr_high(&dl, value);
		break;
	case 2:
		reg_addr_low(&charset, value);
		break;
	case 3:
		reg_addr_high(&charset, value);
		break;
	case 4:
		reg_addr_low(&palette, value);
		break;
	case 5:
		reg_addr_high(&palette, value);
		break;
	case 6:
		page = value & 0x07;
		break;
	case 8:
		CPU_HALT();
		break;
	case 9:
		status = (status & 0x3) | (value & 0xFC);
		break;
	case 0xa:
		reg_addr_low(&sprites, value);
		break;
	case 0xb:
		reg_addr_high(&sprites, value);
		break;
	case 0xc:
		reg_addr_low(&tileset_small, value);
		break;
	case 0xd:
		reg_addr_high(&tileset_small, value);
		break;
	case 0xe:
		reg_addr_low(&tileset_big, value);
		break;
	case 0xf:
		reg_addr_high(&tileset_big, value);
		break;
	case 0x10:
		border_color = value;
		break;
	}
}

UINT8 chroni_register_read(UINT8 index) {
	switch(index) {
	case 6: return page & 0x07;
	case 7: return ypos >> 1;
	case 9: return status;
	}
	return 0;
}

static inline void set_pixel_color(UINT8 color) {
	UINT16 pixel_color_rgb565 = VRAM_WORD(palette + color*2 + 0);

	pixel_color_r = rgb565[pixel_color_rgb565*3 + 0];
	pixel_color_g = rgb565[pixel_color_rgb565*3 + 1];
	pixel_color_b = rgb565[pixel_color_rgb565*3 + 2];
}

#define SPRITE_ATTR_ENABLED 0x10
#define SPRITE_SCAN_INVALID 0xFF

#define SPRITES_MAX   32
#define SPRITES_X     (SPRITES_MAX * 2)
#define SPRITES_Y     (SPRITES_MAX * 2 + SPRITES_X)
#define SPRITES_ATTR  (SPRITES_MAX * 2 + SPRITES_Y)
#define SPRITES_COLOR (SPRITES_MAX * 2 + SPRITES_ATTR)

static UINT8 sprite_scanlines[SPRITES_MAX];

static void do_scan_start() {
	status |= STATUS_HBLANK;
	if (post_dli && (status & STATUS_ENABLE_INTS)) {
		LOGV(LOGTAG, "do_scan_start fire DLI");
		cpuexec_nmi(1);
	}
	post_dli = 0;

	CPU_RUN(22);
	status &= (255 - STATUS_HBLANK);
	cpuexec_nmi(0);

	/*
	 * check all sprites and write the scan to be drawn
	 * assume that the sprite will not be drawn
	 */
	for(int s=0; s < SPRITES_MAX; s++) {
		sprite_scanlines[s] = SPRITE_SCAN_INVALID; // asume invalid sprite for this scan
		if (!(status & STATUS_ENABLE_SPRITES)) continue;

		UINT16 sprite_attrib = VRAM_DATA(sprites + SPRITES_ATTR + s*2);
		if ((sprite_attrib & SPRITE_ATTR_ENABLED) == 0) continue;

		int sprite_y = VRAM_WORD(sprites + SPRITES_Y + s*2) - 16;

		int sprite_scanline = scanline - sprite_y;
		if (sprite_scanline< 0 || sprite_scanline >=16) continue;
		sprite_scanlines[s] = sprite_scanline;
	}
}

static void do_scan_end() {
	CPU_RESUME();
	CPU_RUN(8);
}

static inline PAIR do_sprites() {
	UINT8 dot_color   = 0;
	UINT8 sprite_data = 0;
	for(int s=SPRITES_MAX-1; s>=0 && (status & STATUS_ENABLE_SPRITES); s--) {
		UINT8 sprite_scanline = sprite_scanlines[s];
		if (sprite_scanline == SPRITE_SCAN_INVALID) continue;

		int sprite_x = VRAM_WORD(sprites + SPRITES_X + s*2) - 24;

		int sprite_pixel_x = xpos - sprite_x;
		if (sprite_pixel_x < 0) continue; // not yet
		if (sprite_pixel_x >=16) { // not anymore
			sprite_scanlines[s] = SPRITE_SCAN_INVALID;
			continue;
		}

		int sprite_pointer = VRAM_PTR(sprites + s*2);

		sprite_data = VRAM_DATA(sprite_pointer
				+ (sprite_scanline << 3)
				+ (sprite_pixel_x  >> 1));
		sprite_data = (sprite_pixel_x & 1) == 0 ?
				sprite_data >> 4 :
				sprite_data & 0xF;
		if (sprite_data == 0) continue;

		UINT16 sprite_attrib = VRAM_DATA(sprites + SPRITES_ATTR + s*2);
		int sprite_palette = sprite_attrib & 0x0F;

		dot_color = VRAM_DATA(sprites + SPRITES_COLOR + sprite_palette*16 + sprite_data);
		break;
	}
	PAIR result;
	result.b.l = dot_color;
	result.b.h = sprite_data;
	return result;
}

static void inline put_pixel(int offset, UINT8 color) {
	PAIR sprite = do_sprites();
	UINT8 dot_color = sprite.b.h == 0 ? color : sprite.b.l;

	set_pixel_color(dot_color);
	screen[offset + xpos*3 + 0] = pixel_color_r;
	screen[offset + xpos*3 + 1] = pixel_color_g;
	screen[offset + xpos*3 + 2] = pixel_color_b;
	CPU_XPOS();
}

static void inline do_border(int offset, int size) {
	for(int i=0; i<size; i++) {
		put_pixel(offset, border_color);
	}
}

static void inline do_scan_off(int offset, int size) {
	for(int i=0; i<size; i++) {
		screen[offset + xpos*3 + 0] = 0;
		screen[offset + xpos*3 + 1] = 0;
		screen[offset + xpos*3 + 2] = 0;
		CPU_XPOS();
	}
}

static void do_scan_blank() {
	int offset = scanline * screen_pitch;
	xpos = 0;

	if (status & STATUS_ENABLE_CHRONI) {
		do_scan_start();
		do_border(offset, screen_width);
		do_scan_end();
	} else {
		do_scan_off(offset, screen_width);
	}
}

static void do_scan_text_attribs(UINT8 line) {
	LOGV(LOGTAG, "do_scan_text_attribs line %d", line);
	do_scan_start();

	int offset = scanline * screen_pitch;
	xpos = 0;
	do_border(offset, SCREEN_XBORDER);

	UINT8 row;
	UINT8 foreground, background;
	int char_offset = 0;
	for(int i=0; i<SCREEN_XRES; i++) {
		if (i % 8 == 0) {
			UINT8 attrib = VRAM_DATA(attribs + char_offset);
			foreground = (attrib & 0xF0) >> 4;
			background = attrib & 0x0F;

			UINT8 c = VRAM_DATA(lms + char_offset);
			row = VRAM_DATA(charset + c*8 + line);
			char_offset++;
		}

		put_pixel(offset, row & 0x80 ?
				VRAM_DATA(subpals + foreground) :
				VRAM_DATA(subpals + background));

		row <<= 1;
	}

	do_border(offset, SCREEN_XBORDER);
	do_scan_end();
}

static void do_scan_text_attribs_double(UINT8 line) {
	LOGV(LOGTAG, "do_scan_text_attribs double line %d", line);
	do_scan_start();

	int offset = scanline * screen_pitch;
	xpos = 0;
	do_border(offset, SCREEN_XBORDER);

	UINT8 row;
	UINT8 foreground, background;
	int char_offset = 0;
	bool first = TRUE;
	for(int i=0; i<SCREEN_XRES; i++) {
		if (i % 0x10 == 0) {
			UINT8 attrib = VRAM_DATA(attribs + char_offset);
			foreground = (attrib & 0xF0) >> 4;
			background = attrib & 0x0F;

			UINT8 c = VRAM_DATA(lms + char_offset);
			row = VRAM_DATA(charset + c*8 + line);
			char_offset++;
		}

		put_pixel(offset, row & 0x80 ?
				VRAM_DATA(subpals + foreground) :
				VRAM_DATA(subpals + background));
		if (!first) row <<= 1;
		first = !first;
	}

	do_border(offset, SCREEN_XBORDER);
	do_scan_end();
}

static void do_scan_tile_wide_2bpp(UINT8 line) {
	LOGV(LOGTAG, "do_scan_tile_wide_2bpp line %d", line);
	do_scan_start();

	int offset = scanline * screen_pitch;
	xpos = 0;
	do_border(offset, SCREEN_XBORDER);

	UINT8  palette = 0;
	UINT8  pixel = 0;
	UINT8  pixel_data = 0;
	int tile_offset = 0;
	for(int i=0; i<SCREEN_XRES; i++) {
		if ((i & 7) == 0) {
			palette = VRAM_DATA(attribs + tile_offset);

			UINT8 tile = VRAM_DATA(lms + tile_offset);
			pixel_data = VRAM_DATA(tileset_small + tile*8 + line);
			tile_offset++;
		}

		if ((i & 1) == 0) {
			pixel   = (pixel_data   & 0xC0) >> 6;
			pixel_data <<= 2;
		}

		UINT8 color = VRAM_DATA(subpals + palette*4 + pixel);

		put_pixel(offset, color);
	}

	do_border(offset, SCREEN_XBORDER);
	do_scan_end();
}

static void do_scan_tile_wide_4bpp(UINT8 line) {
	LOGV(LOGTAG, "do_scan_tile_wide_4bpp line %d", line);
	do_scan_start();

	int offset = scanline * screen_pitch;
	xpos = 0;
	do_border(offset, SCREEN_XBORDER);

	UINT8  palette = 0;
	UINT8  pixel = 0;
	UINT8  pixel_data = 0;
	UINT8  tile = 0;
	UINT8  tile_data;
	int tile_offset = 0;
	for(int i=0; i<SCREEN_XRES; i++) {
		if ((i & 31) == 0) {
			palette = VRAM_DATA(attribs + tile_offset);
			tile    = VRAM_DATA(lms + tile_offset);
			tile_data = 0;

			tile_offset++;
		}

		if ((i & 3) == 0) {
			pixel_data = VRAM_DATA(tileset_big + tile*128 + line*8 + tile_data);
			tile_data++;
		}

		if ((i & 1) == 0) {
			pixel   = (pixel_data & 0xF0) >> 4;
			pixel_data <<= 4;
		}

		UINT8 color = VRAM_DATA(subpals + palette*16 + pixel);

		put_pixel(offset, color);
	}

	do_border(offset, SCREEN_XBORDER);
	do_scan_end();
}

static void do_scan_tile_4bpp(UINT8 line) {
	LOGV(LOGTAG, "do_scan_tile_wide_4bpp line %d", line);
	do_scan_start();

	int offset = scanline * screen_pitch;
	xpos = 0;
	do_border(offset, SCREEN_XBORDER);

	UINT8  palette = 0;
	UINT8  pixel = 0;
	UINT8  pixel_data = 0;
	UINT8  tile = 0;
	UINT8  tile_data;
	int tile_offset = 0;
	for(int i=0; i<SCREEN_XRES; i++) {
		if ((i & 15) == 0) {
			palette = VRAM_DATA(attribs + tile_offset);
			tile    = VRAM_DATA(lms + tile_offset);
			tile_data = 0;

			tile_offset++;
		}

		if ((i & 1) == 0) {
			pixel_data = VRAM_DATA(tileset_big + tile*128 + line*8 + tile_data);
			tile_data++;
		}

		pixel   = (pixel_data & 0xF0) >> 4;
		pixel_data <<= 4;

		UINT8 color = VRAM_DATA(subpals + palette*16 + pixel);

		put_pixel(offset, color);
	}

	do_border(offset, SCREEN_XBORDER);
	do_scan_end();
}


static void do_scan_pixels_2bpp() {
	LOGV(LOGTAG, "do_scan_pixels_2bpp line");
	do_scan_start();

	int offset = scanline * screen_pitch;
	xpos = 0;
	do_border(offset, SCREEN_XBORDER);

	UINT8  palette = 0;
	UINT8  palette_data = 0;
	UINT8  pixel = 0;
	UINT8  pixel_data = 0;
	UINT16 pixel_data_offset = 0;
	for(int i=0; i<SCREEN_XRES; i++) {
		if ((i & 3) == 0) {
			LOGV(LOGTAG, "vram offset: %05X pixel:%05X attrib:%05X",
					pixel_data_offset, lms+pixel_data_offset, attribs+pixel_data_offset);
			palette_data = VRAM_DATA(attribs + pixel_data_offset);
			pixel_data = VRAM_DATA(lms + pixel_data_offset);
			pixel_data_offset++;
		}

		pixel   = (pixel_data   & 0xC0) >> 6;
		palette = (palette_data & 0xC0) >> 4;

		pixel_data <<= 2;
		palette_data <<= 2;

		UINT8 color = VRAM_DATA(subpals + palette + pixel);
		LOGV(LOGTAG, "vram data subpals:%05X palette:%04X pixel:%02X color:%02X",
			subpals, palette, pixel, color);

		put_pixel(offset, color);

	}

	do_border(offset, SCREEN_XBORDER);
	do_scan_end();
}


static void do_scan_pixels_4bpp() {
	LOGV(LOGTAG, "do_scan_pixels_4bpp line");
	do_scan_start();

	int offset = scanline * screen_pitch;
	xpos = 0;
	do_border(offset, SCREEN_XBORDER);

	UINT8  palette = 0;
	UINT8  palette_data = 0;
	UINT8  pixel = 0;
	UINT8  pixel_data = 0;
	UINT16 pixel_data_offset = 0;
	for(int i=0; i<SCREEN_XRES; i++) {
		if ((i & 1) == 0) {
			LOGV(LOGTAG, "vram offset: %05X pixel:%05X attrib:%05X",
					pixel_data_offset, lms+pixel_data_offset, attribs+pixel_data_offset);
			palette_data = VRAM_DATA(attribs + pixel_data_offset);
			pixel_data = VRAM_DATA(lms + pixel_data_offset);
			pixel_data_offset++;
		}

		pixel   = (pixel_data   & 0xF0) >> 4;
		palette = (palette_data & 0xF0);

		pixel_data   <<= 4;
		palette_data <<= 4;

		UINT8 color = VRAM_DATA(subpals + palette + pixel);
		LOGV(LOGTAG, "vram data subpals:%05X palette:%04X pixel:%02X color:%02X",
			subpals, palette, pixel, color);

		put_pixel(offset, color);
	}

	do_border(offset, SCREEN_XBORDER);
	do_scan_end();
}

static void do_scan_pixels_wide_2bpp() {
	LOGV(LOGTAG, "do_scan_pixels_wide_2bpp line");
	do_scan_start();

	int offset = scanline * screen_pitch;
	xpos = 0;
	do_border(offset, SCREEN_XBORDER);

	UINT8  palette = 0;
	UINT8  palette_data = 0;
	UINT8  pixel = 0;
	UINT8  pixel_data = 0;
	UINT16 pixel_data_offset = 0;
	for(int i=0; i<SCREEN_XRES; i++) {
		if ((i & 7) == 0) {
			LOGV(LOGTAG, "vram offset: %05X pixel:%05X attrib:%05X",
					pixel_data_offset, lms+pixel_data_offset, attribs+pixel_data_offset);
			palette_data = VRAM_DATA(attribs + pixel_data_offset);
			pixel_data = VRAM_DATA(lms + pixel_data_offset);
			pixel_data_offset++;
		}

		if ((i & 1) == 0) {
			pixel   = (pixel_data   & 0xC0) >> 6;
			palette = (palette_data & 0xC0) >> 2;

			pixel_data <<= 2;
			palette_data <<= 2;
		}

		UINT8 color = VRAM_DATA(subpals + palette + pixel);
		LOGV(LOGTAG, "vram data subpals:%05X palette:%04X pixel:%02X color:%02X",
			subpals, palette, pixel, color);

		put_pixel(offset, color);

	}

	do_border(offset, SCREEN_XBORDER);
	do_scan_end();
}

static void do_scan_pixels_wide_4bpp() {
	LOGV(LOGTAG, "do_scan_pixels_wide_4bpp line");
	do_scan_start();

	int offset = scanline * screen_pitch;
	xpos = 0;
	do_border(offset, SCREEN_XBORDER);

	UINT8  palette = 0;
	UINT8  palette_data = 0;
	UINT8  pixel = 0;
	UINT8  pixel_data = 0;
	UINT16 pixel_data_offset = 0;
	for(int i=0; i<SCREEN_XRES; i++) {
		if ((i & 3) == 0) {
			LOGV(LOGTAG, "vram offset: %05X pixel:%05X attrib:%05X",
					pixel_data_offset, lms+pixel_data_offset, attribs+pixel_data_offset);
			palette_data = VRAM_DATA(attribs + pixel_data_offset);
			pixel_data = VRAM_DATA(lms + pixel_data_offset);
			pixel_data_offset++;
		}

		if ((i & 1) == 0) {
			pixel   = (pixel_data   & 0xF0) >> 4;
			palette = (palette_data & 0xF0);

			pixel_data   <<= 4;
			palette_data <<= 4;
		}

		UINT8 color = VRAM_DATA(subpals + palette + pixel);
		LOGV(LOGTAG, "vram data subpals:%05X palette:%04X pixel:%02X color:%02X",
			subpals, palette, pixel, color);

		put_pixel(offset, color);
	}

	do_border(offset, SCREEN_XBORDER);
	do_scan_end();
}

static void do_scan_pixels_1bpp() {
	LOGV(LOGTAG, "do_scan_pixels_1bpp line");
	do_scan_start();

	int offset = scanline * screen_pitch;
	xpos = 0;
	do_border(offset, SCREEN_XBORDER);

	UINT8  palette = 0;
	UINT8  palette_data = 0;
	UINT8  pixel = 0;
	UINT8  pixel_data = 0;
	UINT16 pixel_data_offset = 0;
	for(int i=0; i<SCREEN_XRES; i++) {
		if ((i & 7) == 0) {
			LOGV(LOGTAG, "vram offset: %05X pixel:%05X attrib:%05X",
					pixel_data_offset, lms+pixel_data_offset, attribs+pixel_data_offset);
			palette_data = VRAM_DATA(attribs + pixel_data_offset);
			pixel_data = VRAM_DATA(lms + pixel_data_offset);
			pixel_data_offset++;
		}

		pixel   = (pixel_data   & 0x80) >> 7;
		palette = (palette_data & 0x80) >> 6;

		pixel_data   <<= 1;
		palette_data <<= 1;

		UINT8 color = VRAM_DATA(subpals + palette + pixel);
		LOGV(LOGTAG, "vram data subpals:%05X palette:%04X pixel:%02X color:%02X",
			subpals, palette, pixel, color);

		put_pixel(offset, color);
	}

	do_border(offset, SCREEN_XBORDER);
	do_scan_end();
}

static UINT8 bytes_per_scan[] = {
		0, 0, 40, 20,
		40, 40, 80, 80,
		40, 80, 160, 40,
		10, 10

};


static void do_screen() {
	/* 0-7 scanlines are not displayed because of vblank
	 *
	 */
	for(ypos = 0; ypos <8; ypos++) {
		CPU_SCANLINE();
	}
	cpuexec_nmi(0);
	LOGV(LOGTAG, "set status %02X enabled:%s", status, (status & STATUS_ENABLE_CHRONI) ? "true":"false");
	status &= (255 - STATUS_VBLANK);
	LOGV(LOGTAG, "set status %02X enabled:%s", status, (status & STATUS_ENABLE_CHRONI) ? "true":"false");

	scanline = 0;

	UINT8 instruction;
	int dlpos = 0;
	while(ypos < screen_height && (status & STATUS_ENABLE_CHRONI)) {
		instruction = VRAM_DATA(dl + dlpos);
		int scan_post_dli = instruction & 0x80;
		LOGV(LOGTAG, "DL instruction %05X = %02X", dl + dlpos, instruction);
		dlpos++;
		UINT8 mode = instruction & 0x0F;

		if (instruction == 0x41) {
			break;
		} else if (mode == 0) { // blank lines
			UINT8 lines = 1 + ((instruction & 0x70) >> 4);
			LOGV(LOGTAG, "do_scan_blank lines %d", lines);
			for(int line=0; line<lines; line++) {
				if (line == lines - 1) post_dli = scan_post_dli;
				do_scan_blank();
				scanline++;
				ypos++;
				if (ypos == screen_height) return;
			}
		} else {
			if (instruction & 64) {
				lms     = VRAM_PTR(dl + dlpos);
				dlpos+=2;
				attribs = VRAM_PTR(dl + dlpos);
				dlpos+=2;
				subpals = VRAM_PTR(dl + dlpos);
				dlpos+=2;
			}

			if (mode == 2) {
				LOGV(LOGTAG, "do_scan_text lms: %04X", lms);
				int lines = 8;
				for(int line=0; line<lines; line++) {
					if (line == lines - 1) post_dli = scan_post_dli;
					do_scan_text_attribs(line);
					scanline++;
					ypos++;
					if (ypos == screen_height) return;
				}
			} else if (mode == 3) {
				LOGV(LOGTAG, "do_scan_text_attrib lms: %04X attrib: %04X", lms, attribs);
				int lines = 8;
				for(int line=0; line<lines; line++) {
					if (line == lines - 1) post_dli = scan_post_dli;
					do_scan_text_attribs_double(line);
					scanline++;
					ypos++;
					if (ypos == screen_height) return;
				}
			} else if (mode == 4) {
				LOGV(LOGTAG, "do_scan_text_attrib lms: %04X attrib: %04X", lms, attribs);
				int lines = 16;
				for(int line=0; line<lines; line++) {
					if (line == lines - 1) post_dli = scan_post_dli;
					do_scan_text_attribs_double(line >> 1);
					scanline++;
					ypos++;
					if (ypos == screen_height) return;
				}
			} else if (mode == 5) {
				do_scan_pixels_wide_2bpp();
				scanline++;
				ypos++;
				if (ypos == screen_height) return;
			} else if (mode == 6) {
				unsigned lines = 2;
				for(int line=0; line<lines; line++) {
					do_scan_pixels_wide_2bpp();
					scanline++;
					ypos++;
					if (ypos == screen_height) return;
				}
			} else if (mode == 7) {
				do_scan_pixels_wide_4bpp();
				scanline++;
				ypos++;
				if (ypos == screen_height) return;
			} else if (mode == 8) {
				unsigned lines = 2;
				for(int line=0; line<lines; line++) {
					do_scan_pixels_wide_4bpp();
					scanline++;
					ypos++;
					if (ypos == screen_height) return;
				}
			} else if (mode == 9) {
				do_scan_pixels_1bpp();
				scanline++;
				ypos++;
				if (ypos == screen_height) return;
			} else if (mode == 0x0A) {
				do_scan_pixels_2bpp();
				scanline++;
				ypos++;
				if (ypos == screen_height) return;
			} else if (mode == 0x0B) {
				do_scan_pixels_4bpp();
				scanline++;
				ypos++;
				if (ypos == screen_height) return;
			} else if (mode == 0x0C) {
				int lines = 8;
				for(int line=0; line<lines; line++) {
					if (line == lines - 1) post_dli = scan_post_dli;
					do_scan_tile_wide_2bpp(line);
					scanline++;
					ypos++;
					if (ypos == screen_height) return;
				}
			} else if (mode == 0x0D) {
				int lines = 16;
				for(int line=0; line<lines; line++) {
					if (line == lines - 1) post_dli = scan_post_dli;
					do_scan_tile_wide_4bpp(line);
					scanline++;
					ypos++;
					if (ypos == screen_height) return;
				}
			} else if (mode == 0x0E) {
				int lines = 16;
				for(int line=0; line<lines; line++) {
					if (line == lines - 1) post_dli = scan_post_dli;
					do_scan_tile_4bpp(line);
					scanline++;
					ypos++;
					if (ypos == screen_height) return;
				}
			}

			UINT8 pitch = bytes_per_scan[mode];
			lms += pitch;
			attribs += pitch;
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
	trace_enabled = TRUE;
	init_rgb565_table();
	chroni_reset();
}

void chroni_run_frame() {
	do_screen();

	status |= STATUS_VBLANK;
	if (status & STATUS_ENABLE_INTS) cpuexec_nmi(1);
}
