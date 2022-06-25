CC = gcc

DEFS =
LIBS = -lm

TARGET = bitmap_processor

CFLAGS = -g -Wall -I../../src

OBJDIR= ../../bin/bitmap

OBJS = $(addprefix $(OBJDIR)/, \
	bitmap_processor.o \
	)

all: $(TARGET)

$(OBJDIR)/%.o: %.c
	@mkdir -p $(dir $@) 2> /dev/null 
	$(CC) -c -o $@ $(DEFS) -I. $(CFLAGS) $<

$(TARGET): $(OBJS)
	$(CC) -o $@ $(LDFLAGS) $(OBJS) $(LIBS)
	

clean:
	rm -f $(TARGET) $(OBJS)
