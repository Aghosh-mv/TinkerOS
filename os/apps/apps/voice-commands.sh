#!/bin/bash
# TinkerOS Voice Commands - Speech recognition hook
echo "=== TinkerOS Voice Commands ==="
echo ""
if command -v whisper &>/dev/null; then
    echo "Whisper available - voice input ready"
elif command -v arecord &>/dev/null; then
    echo "arecord available - mic capture ready"
    echo "  Record: arecord -f cd test.wav"
else
    echo "  No audio capture tool"
fi
echo ""
echo "Configured commands: open browser, lock screen, take screenshot, play music"
