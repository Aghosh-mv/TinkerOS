#!/bin/bash
# TinkerOS Audio Mixer
echo "=== TinkerOS Audio Mixer ==="
echo ""
if command -v pactl &>/dev/null; then
    echo "Sinks:"
    pactl list short sinks 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "Sources:"
    pactl list short sources 2>/dev/null | sed 's/^/  /'
else
    echo "  PulseAudio not available"
fi
