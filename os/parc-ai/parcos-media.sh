#!/usr/bin/env bash
# korrinos-media.sh — Media Hub for KorrinOS
# Photo manager, music player, video player, screen recording

set -euo pipefail

MEDIA_DIR="${HOME}/.local/share/korrinos/media"
PHOTO_DIR="$HOME/Pictures"
MUSIC_DIR="$HOME/Music"
VIDEO_DIR="$HOME/Videos"

mkdir -p "$MEDIA_DIR"

# Photo operations
media_photo_list() {
  local dir="${1:-$PHOTO_DIR}"
  echo "=== Photos in $dir ==="
  find "$dir" -maxdepth 3 -type f \
    \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" \
    -o -name "*.webp" -o -name "*.bmp" -o -name "*.tiff" \) \
    2>/dev/null | head -30
}

media_photo_info() {
  local image="$1"
  if command -v exiftool &>/dev/null; then
    exiftool "$image" 2>/dev/null | head -20
  elif command -v identify &>/dev/null; then
    identify -verbose "$image" 2>/dev/null | head -20
  else
    file "$image"
  fi
}

media_photo_resize() {
  local input="$1"
  local output="$2"
  local width="${3:-1920}"
  
  if command -v convert &>/dev/null; then
    convert "$input" -resize "$width>" "$output"
    echo "Resized: $output"
  else
    echo "ImageMagick not installed"
  fi
}

media_photo_collage() {
  local output="$1"
  shift
  
  if command -v convert &>/dev/null; then
    convert "$@" -resize 300x300 -tile 3x3 -geometry +5+5 "$output"
    echo "Collage created: $output"
  fi
}

# Music operations
media_music_list() {
  local dir="${1:-$MUSIC_DIR}"
  echo "=== Music in $dir ==="
  find "$dir" -maxdepth 3 -type f \
    \( -name "*.mp3" -o -name "*.flac" -o -name "*.wav" -o -name "*.m4a" \
    -o -name "*.ogg" -o -name "*.wma" \) \
    2>/dev/null | head -30
}

media_music_play() {
  local file="$1"
  
  if command -v mpv &>/dev/null; then
    mpv "$file" &
  elif command -v vlc &>/dev/null; then
    vlc "$file" &
  elif command -v ffplay &>/dev/null; then
    ffplay "$file" &
  else
    echo "No media player found"
  fi
}

media_music_info() {
  local file="$1"
  if command -v ffprobe &>/dev/null; then
    ffprobe -v quiet -print_format json -show_format "$file" 2>/dev/null
  fi
}

media_music_playlist() {
  local dir="${1:-$MUSIC_DIR}"
  local output="${2:-playlist.m3u}"
  
  echo "#EXTM3U" > "$output"
  find "$dir" -maxdepth 3 -type f \
    \( -name "*.mp3" -o -name "*.flac" -o -name "*.wav" \) \
    2>/dev/null | while read -r f; do
    echo "$f" >> "$output"
  done
  echo "Playlist created: $output"
}

# Video operations
media_video_list() {
  local dir="${1:-$VIDEO_DIR}"
  echo "=== Videos in $dir ==="
  find "$dir" -maxdepth 3 -type f \
    \( -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" -o -name "*.mov" \
    -o -name "*.webm" -o -name "*.flv" \) \
    2>/dev/null | head -30
}

media_video_play() {
  local file="$1"
  
  if command -v mpv &>/dev/null; then
    mpv "$file" &
  elif command -v vlc &>/dev/null; then
    vlc "$file" &
  else
    echo "No video player found"
  fi
}

media_video_info() {
  local file="$1"
  if command -v ffprobe &>/dev/null; then
    ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null
  fi
}

media_video_convert() {
  local input="$1"
  local output="$2"
  local format="${3:-mp4}"
  
  if command -v ffmpeg &>/dev/null; then
    ffmpeg -i "$input" "$output" -y
    echo "Converted: $output"
  else
    echo "FFmpeg not installed"
  fi
}

media_video_compress() {
  local input="$1"
  local output="$2"
  
  if command -v ffmpeg &>/dev/null; then
    ffmpeg -i "$input" -c:v libx264 -crf 28 -preset fast "$output" -y
    echo "Compressed: $output"
  fi
}

# Screen recording
media_record_screen() {
  local output="${1:-/tmp/recording_$(date +%Y%m%d_%H%M%S).mp4}"
  
  if command -v obs &>/dev/null; then
    echo "OBS Studio available - use GUI"
  elif command -v ffmpeg &>/dev/null; then
    echo "Recording to $output (Ctrl+C to stop)..."
    ffmpeg -f x11grab -r 30 -i :0.0 "$output" 2>/dev/null
  else
    echo "No screen recording tool found"
  fi
}

media_record_stop() {
  pkill -f ffmpeg 2>/dev/null && echo "Recording stopped" || echo "No recording found"
}

# Subtitle search
media_subtitle_search() {
  local file="$1"
  local lang="${2:-en}"
  
  echo "Searching subtitles for: $file"
  
  if command -v subliminal &>/dev/null; then
    subliminal download -l "$lang" "$file"
  else
    echo "Install subliminal: pip install subliminal"
  fi
}

# Media library scan
media_scan() {
  echo "=== Media Library Scan ==="
  echo ""
  
  echo "Photos:"
  media_photo_list | wc -l
  echo ""
  
  echo "Music:"
  media_music_list | wc -l
  echo ""
  
  echo "Videos:"
  media_video_list | wc -l
}

case "${1:-help}" in
  photo)
    shift
    case "${1:-list}" in
      list)     shift; media_photo_list "$@" ;;
      info)     shift; media_photo_info "$@" ;;
      resize)   shift; media_photo_resize "$@" ;;
      collage)  shift; media_photo_collage "$@" ;;
    esac
    ;;
  music)
    shift
    case "${1:-list}" in
      list)       shift; media_music_list "$@" ;;
      play)       shift; media_music_play "$@" ;;
      info)       shift; media_music_info "$@" ;;
      playlist)   shift; media_music_playlist "$@" ;;
    esac
    ;;
  video)
    shift
    case "${1:-list}" in
      list)       shift; media_video_list "$@" ;;
      play)       shift; media_video_play "$@" ;;
      info)       shift; media_video_info "$@" ;;
      convert)    shift; media_video_convert "$@" ;;
      compress)   shift; media_video_compress "$@" ;;
    esac
    ;;
  record)
    shift
    case "${1:-start}" in
      start)  shift; media_record_screen "$@" ;;
      stop)   media_record_stop ;;
    esac
    ;;
  subtitle)  shift; media_subtitle_search "$@" ;;
  scan)      media_scan ;;
  *)
    echo "KorrinOS Media Hub"
    echo "Usage: korrinos-media.sh <command>"
    echo ""
    echo "Commands:"
    echo "  photo (list|info|resize|collage)"
    echo "  music (list|play|info|playlist)"
    echo "  video (list|play|info|convert|compress)"
    echo "  record (start|stop)"
    echo "  subtitle <file> [lang]"
    echo "  scan                Scan media library"
    ;;
esac
