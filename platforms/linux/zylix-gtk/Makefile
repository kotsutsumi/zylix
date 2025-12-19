# Zylix GTK4 Makefile

# Compiler settings
CC = gcc
CFLAGS = -Wall -Wextra -O2 $(shell pkg-config --cflags gtk4)
LDFLAGS = $(shell pkg-config --libs gtk4) -L../../../core/zig-out/linux-x64 -lzylix -lm

# Directories
SRCDIR = .
BUILDDIR = build
CORE_LIB = ../../../core/zig-out/linux-x64/libzylix.a

# Files
TARGET = $(BUILDDIR)/zylix-counter
SOURCES = $(SRCDIR)/main.c
OBJECTS = $(BUILDDIR)/main.o

# Default target
all: $(TARGET)

# Create build directory
$(BUILDDIR):
	mkdir -p $(BUILDDIR)

# Compile main.c
$(BUILDDIR)/main.o: $(SRCDIR)/main.c $(SRCDIR)/zylix.h | $(BUILDDIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Link
$(TARGET): $(OBJECTS) $(CORE_LIB)
	$(CC) $(OBJECTS) $(CORE_LIB) $(LDFLAGS) -o $@

# Build Zig core library
$(CORE_LIB):
	cd ../../../core && zig build linux-x64 -Doptimize=ReleaseFast

# Clean
clean:
	rm -rf $(BUILDDIR)

# Run
run: $(TARGET)
	$(TARGET)

# Debug build
debug: CFLAGS += -g -DDEBUG
debug: $(TARGET)

# Install (requires root)
install: $(TARGET)
	install -Dm755 $(TARGET) /usr/local/bin/zylix-counter

# Uninstall
uninstall:
	rm -f /usr/local/bin/zylix-counter

.PHONY: all clean run debug install uninstall
