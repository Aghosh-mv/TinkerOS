# TinkerOS hardware-tech C backends
# Safe, capability-probing physical drivers for TinkerOS hardware features.
# Compiled locally (gcc). No network, no dependencies beyond libc.

CC      ?= gcc
CFLAGS  ?= -O2 -Wall -Wextra -std=gnu11
SRCDIR  := src
BINDIR  := bin

BINS := msr_control cat_control thermal_control fan_control display_control battery_control fpga_control audio_control device_weights

all: $(BINS)

%: $(SRCDIR)/%.c
	$(CC) $(CFLAGS) -o $(BINDIR)/$@ $<

device_weights: ../lib/device-weights.c
	$(CC) $(CFLAGS) -o $(BINDIR)/$@ ../lib/device-weights.c

clean:
	rm -f $(addprefix $(BINDIR)/,$(BINS))

install: all
	@echo "Binaries built in $(BINDIR)/. Run with sudo for raw access;"
	@echo "each binary probes capability and falls back safely."

.PHONY: all clean install
