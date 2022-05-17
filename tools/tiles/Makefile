CC = gcc

DEFS =
LIBS = -lm

TARGET = extractor

CFLAGS = -g -Wall -I../../src
CFLAGS += $(shell pkg-config --cflags libpng16)
LIBS += $(shell pkg-config --libs libpng16)

OBJDIR= ../../bin/tiles

OBJS = $(addprefix $(OBJDIR)/, \
	readpng.o  \
	extractor.o  \
	)

all: $(TARGET)

$(OBJDIR)/%.o: %.c
	@mkdir -p $(dir $@) 2> /dev/null 
	$(CC) -c -o $@ $(DEFS) -I. $(CFLAGS) $<

$(TARGET): $(OBJS)
	$(CC) -o $@ $(LDFLAGS) $(OBJS) $(LIBS)
	

clean:
	rm -f $(TARGET) $(OBJS)
