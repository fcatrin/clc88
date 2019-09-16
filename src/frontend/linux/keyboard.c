#include <SDL.h>
#include "../../emu.h"
#include "../../input/scancodes.h"

#define LOGTAG "KEYB_IN"
#ifdef TRACE_KEYB_IN
#define TRACE
#endif
#include "trace.h"


static int translation_table[] = {
		SDLK_ESCAPE, SCANCODE_ESC,
		SDLK_F1,  SCANCODE_F1,
		SDLK_F2,  SCANCODE_F2,
		SDLK_F3,  SCANCODE_F3,
		SDLK_F4,  SCANCODE_F4,
		SDLK_F5,  SCANCODE_F5,
		SDLK_F6,  SCANCODE_F6,
		SDLK_F7,  SCANCODE_F7,
		SDLK_F8,  SCANCODE_F8,
		SDLK_F9,  SCANCODE_F9,
		SDLK_F10, SCANCODE_F10,
		SDLK_F11, SCANCODE_F11,
		SDLK_F12, SCANCODE_F12,

		SDLK_RIGHT, SCANCODE_RIGHT,
		SDLK_LEFT,  SCANCODE_LEFT,
		SDLK_DOWN,  SCANCODE_DOWN,
		SDLK_UP,    SCANCODE_UP,

		SDLK_BACKQUOTE, SCANCODE_GRAVE,
		SDLK_1, SCANCODE_1,
		SDLK_2, SCANCODE_2,
		SDLK_3, SCANCODE_3,
		SDLK_4, SCANCODE_4,
		SDLK_5, SCANCODE_5,
		SDLK_6, SCANCODE_6,
		SDLK_7, SCANCODE_7,
		SDLK_8, SCANCODE_8,
		SDLK_9, SCANCODE_9,
		SDLK_0, SCANCODE_0,
		SDLK_MINUS,     SCANCODE_MINUS,
		SDLK_PLUS,      SCANCODE_PLUS,
		SDLK_BACKSLASH, SCANCODE_BACKSLASH,
		SDLK_BACKSPACE, SCANCODE_BACK,

		SDLK_TAB, SCANCODE_TAB,
		SDLK_q, SCANCODE_Q,
		SDLK_w, SCANCODE_W,
		SDLK_e, SCANCODE_E,
		SDLK_r, SCANCODE_R,
		SDLK_t, SCANCODE_T,
		SDLK_y, SCANCODE_Y,
		SDLK_u, SCANCODE_U,
		SDLK_i, SCANCODE_I,
		SDLK_o, SCANCODE_O,
		SDLK_p, SCANCODE_P,
		SDLK_LEFTBRACKET ,SCANCODE_BRACKET_OPEN,
		SDLK_RIGHTBRACKET ,SCANCODE_BRACKET_CLOSE,
		SDLK_RETURN ,SCANCODE_ENTER,

		SDLK_CAPSLOCK, SCANCODE_CAPS,
		SDLK_a, SCANCODE_A,
		SDLK_s, SCANCODE_S,
		SDLK_d, SCANCODE_D,
		SDLK_f, SCANCODE_F,
		SDLK_g, SCANCODE_G,
		SDLK_h, SCANCODE_H,
		SDLK_j, SCANCODE_J,
		SDLK_k, SCANCODE_K,
		SDLK_l, SCANCODE_L,
		SDLK_SEMICOLON, SCANCODE_COLON,
		SDLK_QUOTE,     SCANCODE_QUOTE,

		SDLK_LSHIFT, SCANCODE_LEFT_SHIFT,
		SDLK_z, SCANCODE_Z,
		SDLK_x, SCANCODE_X,
		SDLK_c, SCANCODE_C,
		SDLK_v, SCANCODE_V,
		SDLK_b, SCANCODE_B,
		SDLK_n, SCANCODE_N,
		SDLK_m, SCANCODE_M,
		SDLK_LESS,    SCANCODE_LESS,
		SDLK_GREATER, SCANCODE_GREATER,
		SDLK_SLASH,   SCANCODE_SLASH,

		SDLK_RSHIFT,  SCANCODE_RIGHT_SHIFT,
		SDLK_LCTRL, SCANCODE_LEFT_CTRL,
		SDLK_LALT,  SCANCODE_LEFT_ALT,
		SDLK_LGUI,  SCANCODE_LEFT_META,
		SDLK_SPACE, SCANCODE_SPACE,
		SDLK_RGUI,  SCANCODE_RIGHT_META,
		SDLK_RALT,  SCANCODE_RIGHT_ALT,
		SDLK_RCTRL, SCANCODE_RIGHT_CTRL,

		// probably only in ES layout
		44, SCANCODE_COMMA,
		46, SCANCODE_DOT,
		123, SCANCODE_BRACKET_OPEN,
		125, SCANCODE_BRACKET_CLOSE,

		0
};

#define KEY_REGISTERS 16

static UINT8 regs[KEY_REGISTERS];

void keyb_init() {
	memset(regs, 0, KEY_REGISTERS*sizeof(UINT8));
}

void keyb_done() {}

static int keyb_translate(int keycode) {
	int i=0;

	while(translation_table[i] && translation_table[i] != keycode) {
		i+=2;
	}

	return translation_table[i+1];
}

void keyb_update(int keycode, bool down) {
	int translated = keyb_translate(keycode);
	if (!translated) {
		LOGV(LOGTAG, "Non translated scan code %d", keycode);
		return;
	}

	int bit_index = translated - 1;
	int reg = bit_index / 8;
	int rot = bit_index % 8;


	int bit = 1 << (7-rot);
	LOGV(LOGTAG, "keyb update scancode: %d, reg: %d bit: %d %s", translated, reg, bit, down ? "ON":"OFF");
	if (down) {
		regs[reg] = regs[reg] | bit;
	} else {
		regs[reg] = regs[reg] & (0xFF - bit);
	}

	if (translated < SCANCODE_LEFT_SHIFT || translated > SCANCODE_RIGHT_META) {
		UINT8 last_scan = (UINT8)translated;
		int last_scan_reg = KEY_REGISTERS-1;

		regs[last_scan_reg] = down ? last_scan : 0;
	}
}

UINT8 keyb_get_reg(int reg) {
	return (reg < KEY_REGISTERS) ? regs[reg] : 0;
}

