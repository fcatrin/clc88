FRONTEND = linux

CC = gcc

DEFS = -DHAVE_CONFIG_H -DINLINE=inline -DTRACE -DMAME_DEBUG
LIBS = -lm -lz 

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
	debug.o \
	sound/filter.o \
	sound/mixer.o \
	sound/streams.o \
	sound/sound_interface.o \
	cpu/z80/z80.o \
	cpu/z80/z80dasm.o \
	cpu/m6502/m6502.o \
	cpu/m6502/6502dasm.o \
	sound/pokey/pokey.o \
	video/screen.o \
	video/chroni.o \
	)

ifeq ($(FRONTEND), linux)

OBJS += $(addprefix $(OBJDIR)/, \
	frontend/linux/frontend.o \
	)
	
CFLAGS += $(shell pkg-config --cflags sdl2)
LIBS += $(shell pkg-config --libs sdl2)

endif
	
all: $(FINALTARGET)	

$(OBJDIR)/%.o: %.c
	@mkdir -p $(dir $@) 2> /dev/null 
	$(CC) -c -o $@ $(DEFS) -I. $(CFLAGS) $<

$(TARGET): $(OBJS)
	$(CC) -o $@ $(LDFLAGS) $(OBJS) $(LIBS)
	
	
clean:
	rm $(TARGET) $(OBJS)
	