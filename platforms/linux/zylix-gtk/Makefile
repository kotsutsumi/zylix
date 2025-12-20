# Zylix GTK4 Makefile

# Compiler settings
CC = gcc
CFLAGS = -Wall -Wextra -O2 $(shell pkg-config --cflags gtk4)
LDFLAGS = $(shell pkg-config --libs gtk4) -lm

# Directories
SRCDIR = .
BUILDDIR = build

# Targets
COUNTER = $(BUILDDIR)/zylix-counter
TODO = $(BUILDDIR)/zylix-todo

# Default target - build both apps
all: $(COUNTER) $(TODO)

# Create build directory
$(BUILDDIR):
	mkdir -p $(BUILDDIR)

# Counter app
$(BUILDDIR)/main.o: $(SRCDIR)/main.c $(SRCDIR)/zylix.h | $(BUILDDIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(COUNTER): $(BUILDDIR)/main.o | $(BUILDDIR)
	$(CC) $^ $(LDFLAGS) -o $@

# Todo app
$(BUILDDIR)/todo_app.o: $(SRCDIR)/todo_app.c $(SRCDIR)/zylix.h | $(BUILDDIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(TODO): $(BUILDDIR)/todo_app.o | $(BUILDDIR)
	$(CC) $^ $(LDFLAGS) -o $@

# Individual targets
counter: $(COUNTER)
todo: $(TODO)

# Clean
clean:
	rm -rf $(BUILDDIR)

# Run targets
run-counter: $(COUNTER)
	$(COUNTER)

run-todo: $(TODO)
	$(TODO)

run: run-todo

# Debug build
debug: CFLAGS += -g -DDEBUG
debug: all

# Install (requires root)
install: all
	install -Dm755 $(COUNTER) /usr/local/bin/zylix-counter
	install -Dm755 $(TODO) /usr/local/bin/zylix-todo

# Uninstall
uninstall:
	rm -f /usr/local/bin/zylix-counter
	rm -f /usr/local/bin/zylix-todo

.PHONY: all counter todo clean run run-counter run-todo debug install uninstall
