CC = gcc

DEFS = -DHAVE_CONFIG_H -DINLINE=inline
# DEFS += -DTRACE_MAIN
# DEFS += -DTRACE_FRONTEND
DEFS += -DDUMP_AUDIO

LIBS = -lm -lz -lpthread

TARGET_BASE_NAME = claudio_test

FINALTARGET = $(TARGET_BASE_NAME)
TARGET = $(FINALTARGET)

CFLAGS = -g -Wall

OBJDIR= ../obj

OBJS = $(addprefix $(OBJDIR)/, \
	main.o \
	sound.o \
	screen.o \
	trace.o \
	frontend.o \
	tracker/tracker.o \
	tracker/tracker_utils.o \
	tracker/song.o \
	tracker/pattern.o \
	sound/claudio.o \
	)

CFLAGS += $(shell pkg-config --cflags sdl2)
LIBS += $(shell pkg-config --libs sdl2)

all: $(FINALTARGET)

$(OBJDIR)/%.o: %.c
	@mkdir -p $(dir $@) 2> /dev/null 
	$(CC) -c -o $@ $(DEFS) -I. $(CFLAGS) $<

$(TARGET): $(OBJS)
	$(CC) -o $@ $(LDFLAGS) $(OBJS) $(LIBS)
	

clean:
	rm -f $(TARGET) $(OBJS) $(XEX)
