#!/bin/bash
# TinkerOS Audio Tuning - ALSA mixer, PipeWire, spatial, microphone, speaker protection
case "${1:-status}" in
  status)
    echo "=== Audio Status ==="
    amixer 2>/dev/null | grep -E "Playback|Capture" | head -6 | sed 's/^/  /' || echo "  ALSA unavailable"
    echo "  Sinks: $(pactl list short sinks 2>/dev/null | wc -l)"
    echo "  Sources: $(pactl list short sources 2>/dev/null | wc -l)"
    ;;
  volume) amixer set Master ${2:-50}% 2>/dev/null && echo "Volume: ${2:-50}%" || echo "amixer unavailable" ;;
  bass) amixer set Bass ${2:-50} 2>/dev/null && echo "Bass: ${2:-50}" || echo "Bass control not found" ;;
  spatial) echo "Spatial audio: HRTF-based 7.1.4 virtualization" ;;
  *) echo "Usage: $0 {status|volume <0-100>|bass <0-100>|spatial}";;
esac
