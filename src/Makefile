FRONTEND = linux

CC = gcc

DEFS = -DHAVE_CONFIG_H -DINLINE=inline -DMAME_DEBUG -DHAS_YM2608
# DEFS += -DTRACE_COMPY
# DEFS += -DTRACE_CPU 
# DEFS += -DTRACE_BUS 
# DEFS += -DTRACE_CHRONI
# DEFS += -DTRACE_UTILS
# DEFS += -DTRACE_STORAGE
# DEFS += -DTRACE_KEYB
# DEFS += -DTRACE_KEYB_IN
# DEFS += -DDUMP_AUDIO

DEFS += -DEMULATE_FPGA

LIBS = -lm -lz -lpthread

TARGET_BASE_NAME = clc88

FINALTARGET = $(TARGET_BASE_NAME)
TARGET = $(FINALTARGET)

CFLAGS = -g -Wall

OBJDIR= ../obj

OBJS = $(addprefix $(OBJDIR)/, \
	clc88.o \
	cpu.o \
	bus.o \
	memory.o \
	machine.o \
	timer.o \
	utils.o \
	cpuexec.o \
	storage.o \
	monitor.o \
	debug.o \
	trace.o \
	keyb.o \
	sound.o \
	sound/filter.o \
	sound/mixer.o \
	sound/streams.o \
	sound/sound_interface.o \
	cpu/z80/z80.o \
	cpu/z80/z80dasm.o \
	cpu/m6502/m6502.o \
	cpu/m6502/6502dasm.o \
	sound/pokey/pokey.o \
	sound/ay8910/ay8910.o \
	sound/opn/ymdeltat.o \
	sound/opn/2608intf.o \
	sound/opn/fm.o \
	video/screen.o \
	video/chroni.o \
	)

ASMDIR= ../asm
XEX = $(addprefix $(ASMDIR)/, \
	6502/os/6502os.xex \
	6502/test/modes/mode_0_attribs.xex \
	6502/test/modes/mode_0.xex \
	6502/test/modes/mode_1_attribs.xex \
	6502/test/modes/mode_1.xex \
	6502/test/modes/mode_2.xex \
	6502/test/modes/mode_3.xex \
	6502/test/sprites.xex \
	6502/test/scroll.xex \
	6502/test/storage.xex \
	6502/test/storage_block.xex \
	6502/test/storage_list.xex \
	6502/test/sound.xex \
	)

	#6502/test/modes/mode_4.xex \
	6502/test/modes/mode_5.xex \
	6502/test/modes/mode_6.xex \
	6502/test/modes/mode_7.xex \
	6502/test/modes/mode_8.xex \
	6502/test/modes/mode_9.xex \
	6502/test/modes/mode_a.xex \
	6502/test/modes/mode_b.xex \
	6502/test/modes/mode_c.xex \
	6502/test/modes/mode_d.xex \
	6502/test/keyb.xex \
	6502/test/memopad.xex \
	6502/test/vclock_rand.xex \
	6502/demos/rmt/music.xex \
	6502/demos/rmtplayer/player.xex \
	6502/tools/charset_editor/editor.xex 

ifeq ($(FRONTEND), linux)

OBJS += $(addprefix $(OBJDIR)/, \
	frontend/linux/frontend.o \
	frontend/linux/keyboard.o \
	)
	
CFLAGS += $(shell pkg-config --cflags sdl2)
LIBS += $(shell pkg-config --libs sdl2)

endif
	
all: $(FINALTARGET) samples

$(OBJDIR)/%.o: %.c
	@mkdir -p $(dir $@) 2> /dev/null 
	$(CC) -c -o $@ $(DEFS) -I. $(CFLAGS) $<

$(ASMDIR)/%.xex: $(ASMDIR)/%.asm $(ASMDIR)/6502/os/symbols.asm $(ASMDIR)/6502/os/stdlib.asm
	mads $< -l -s -o:$@
	
$(ASMDIR)/6502/os/6502os.xex : $(ASMDIR)/6502/os/graphics.asm $(ASMDIR)/6502/os/storage.asm 	
$(ASMDIR)/6502/test/memopad.xex: $(ASMDIR)/6502/os/keyboard.asm
$(ASMDIR)/6502/demos/rmt/music.xex: $(ASMDIR)/6502/demos/rmt/rmtplayr.asm
$(ASMDIR)/6502/demos/rmtplayer/player.xex: $(ASMDIR)/6502/demos/rmtplayer/files.asm $(ASMDIR)/6502/demos/rmtplayer/loader.asm
$(ASMDIR)/6502/tools/charset_editor/editor.xex: $(ASMDIR)/6502/tools/charset_editor/charset_nav.asm  $(ASMDIR)/6502/tools/charset_editor/charpix_nav.asm

$(TARGET): $(OBJS)
	$(CC) -o $@ $(LDFLAGS) $(OBJS) $(LIBS)
	
samples: $(XEX)


clean:
	rm -f $(TARGET) $(OBJS) $(XEX)
	