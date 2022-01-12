
CC = gcc
CFLAGS = -g -Wall -I../include
DEFS = -DTRACE_SERIAL
LIBS = 

TARGET = upload

HEADERS = serial_interface.h serial_emulator.h

OBJDIR= obj
OBJS += $(addprefix $(OBJDIR)/, \
	../lib/trace.o \
	upload.o \
	serial_emulator.o \
	)

ALL: $(TARGET)

$(OBJDIR)/%.o: %.c
	@mkdir -p $(dir $@) 2> /dev/null 
	$(CC) -c -o $@ $(DEFS) -I. $(CFLAGS) $<


$(TARGET): $(HEADERS) $(OBJS)
	$(CC) -o $@ $(LDFLAGS) $(OBJS) $(LIBS)


clean:
	rm -rf $(TARGET) $(OBJDIR)
