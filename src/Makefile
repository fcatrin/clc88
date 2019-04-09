CC = gcc

DEFS = -DHAVE_CONFIG_H -DINLINE=inline
LIBS = -lm -lz 

TARGET_BASE_NAME = clc88

FINALTARGET = $(TARGET_BASE_NAME)
TARGET = $(FINALTARGET)

CFLAGS = -O2 -Wall

OBJDIR= ../obj

OBJS = $(addprefix $(OBJDIR)/, \
	clc88.o \
	cpu.o)
	
all: prepare $(FINALTARGET)	

prepare:
	mkdir -p $(OBJDIR)

$(OBJDIR)/%.o: %.c
	$(CC) -c -o $@ $(DEFS) -I. $(CFLAGS) $<

$(TARGET): $(OBJS)
	$(CC) -o $@ $(LDFLAGS) $(OBJS) $(LIBS)
	
	
clean:
	rm $(TARGET) $(OBJS)
	