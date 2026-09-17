#!/usr/bin/env bash
# productivity.sh — calendar, reminders, todos, email, document parsing

TINKER_AI_HOME="${TINKER_AI_HOME:-$HOME/.config/vokk}"
PROD_DIR="$TINKER_AI_HOME/productivity"
mkdir -p "$PROD_DIR/todos" "$PROD_DIR/reminders" "$PROD_DIR/calendar"

# --- TODO LIST ---
ai_todo_add() {
  local text="$1" priority="${2:-medium}" due="${3:-}"
  local id="todo_$(date +%s)_$$"
  local file="$PROD_DIR/todos/$id.json"
  cat > "$file" <<EOJSON
{"id":"$id","text":"$text","priority":"$priority","due":"$due","created":"$(date -Iseconds)","status":"pending"}
EOJSON
  echo "Added: $text (priority: $priority${due:+, due: $due})"
}

ai_todo_list() {
  local filter="${1:-all}"
  echo "=== TODO List ==="
  local found=0
  for f in "$PROD_DIR/todos"/*.json; do
    [ -f "$f" ] || continue
    local text priority status due
    text=$(python3 -c "import json; print(json.load(open('$f'))['text'])" 2>/dev/null)
    priority=$(python3 -c "import json; print(json.load(open('$f'))['priority'])" 2>/dev/null)
    status=$(python3 -c "import json; print(json.load(open('$f'))['status'])" 2>/dev/null)
    due=$(python3 -c "import json; print(json.load(open('$f')).get('due',''))" 2>/dev/null)
    if [ "$filter" != "all" ] && [ "$status" != "$filter" ]; then continue; fi
    local icon="○"; [ "$status" = "done" ] && icon="●"
    [ "$priority" = "high" ] && icon="!"
    echo "$icon $text ${due:+(due: $due)}"
    found=1
  done
  [ "$found" -eq 0 ] && echo "  (empty)"
}

ai_todo_done() {
  local id_or_text="$1"
  for f in "$PROD_DIR/todos"/*.json; do
    [ -f "$f" ] || continue
    local text; text=$(python3 -c "import json; print(json.load(open('$f'))['text'])" 2>/dev/null)
    local id; id=$(basename "$f" .json)
    if [[ "$text" == *"$id_or_text"* ]] || [[ "$id" == *"$id_or_text"* ]]; then
      python3 -c "import json; d=json.load(open('$f')); d['status']='done'; json.dump(d,open('$f','w'))" 2>/dev/null
      echo "Completed: $text"; return 0
    fi
  done
  echo "Not found: $id_or_text"
}

ai_todo_clear() {
  rm -f "$PROD_DIR/todos"/*.json 2>/dev/null
  echo "All todos cleared."
}

# --- CALENDAR ---
ai_cal_add() {
  local title="$1" date="$2" time="${3:-00:00}" duration="${4:-60}"
  local id="cal_$(date +%s)_$$"
  cat > "$PROD_DIR/calendar/$id.json" <<EOJSON
{"id":"$id","title":"$title","date":"$date","time":"$time","duration_min":$duration,"created":"$(date -Iseconds)"}
EOJSON
  echo "Scheduled: $title on $date at $time (${duration}min)"
}

ai_cal_today() {
  local today=$(date +%Y-%m-%d)
  echo "=== Today's Schedule ==="
  local found=0
  for f in "$PROD_DIR/calendar"/*.json; do
    [ -f "$f" ] || continue
    local d; d=$(python3 -c "import json; print(json.load(open('$f'))['date'])" 2>/dev/null)
    [ "$d" = "$today" ] || continue
    local title time dur
    title=$(python3 -c "import json; print(json.load(open('$f'))['title'])" 2>/dev/null)
    time=$(python3 -c "import json; print(json.load(open('$f'))['time'])" 2>/dev/null)
    dur=$(python3 -c "import json; print(json.load(open('$f'))['duration_min'])" 2>/dev/null)
    echo "  $time — $title (${dur}min)"
    found=1
  done
  [ "$found" -eq 0 ] && echo "  (nothing scheduled)"
}

ai_cal_week() {
  echo "=== This Week ==="
  for i in $(seq 0 6); do
    local day=$(date -d "+${i} days" +%Y-%m-%d 2>/dev/null || date -v+${i}d +%Y-%m-%d 2>/dev/null)
    local dow=$(date -d "+${i} days" +%A 2>/dev/null || date -v+${i}d +%A 2>/dev/null)
    echo "$dow ($day):"
    local found=0
    for f in "$PROD_DIR/calendar"/*.json; do
      [ -f "$f" ] || continue
      local d; d=$(python3 -c "import json; print(json.load(open('$f'))['date'])" 2>/dev/null)
      [ "$d" = "$day" ] || continue
      local title time;
      title=$(python3 -c "import json; print(json.load(open('$f'))['title'])" 2>/dev/null)
      time=$(python3 -c "import json; print(json.load(open('$f'))['time'])" 2>/dev/null)
      echo "    $time — $title"
      found=1
    done
    [ "$found" -eq 0 ] && echo "    (free)"
  done
}

# --- EMAIL DRAFT ---
ai_email_draft() {
  local to="$1" subject="$2" body="${3:-}" tone="${4:-professional}"
  echo "To: $to"
  echo "Subject: $subject"
  echo ""
  if [ -n "$body" ]; then
    echo "$body"
  else
    case "$tone" in
      formal)
        echo "Dear $to,"
        echo ""
        echo "I am writing regarding $subject."
        echo ""
        echo "Please let me know if you need any additional information."
        echo ""
        echo "Best regards"
        ;;
      casual)
        echo "Hey $to,"
        echo ""
        echo "About $subject — wanted to reach out."
        echo ""
        echo "Let me know what you think!"
        echo ""
        echo "Cheers"
        ;;
      *)
        echo "Hi $to,"
        echo ""
        echo "I hope this message finds you well. I am writing about $subject."
        echo ""
        echo "Please don't hesitate to reach out with any questions."
        echo ""
        echo "Kind regards"
        ;;
    esac
  fi
}

# --- DOCUMENT PARSING ---
ai_doc_parse() {
  local file="$1"
  if [ ! -f "$file" ]; then echo "File not found: $file"; return 1; fi
  local ext="${file##*.}"
  case "$ext" in
    txt|md)
      echo "=== $(basename "$file") ==="
      wc -w "$file" | awk '{print "Words: "$1}'
      wc -l "$file" | awk '{print "Lines: "$1}'
      head -20 "$file"
      ;;
    csv)
      head -5 "$file"
      echo "..."
      wc -l "$file" | awk '{print "Total rows: "$1}'
      ;;
    json)
      python3 -m json.tool "$file" 2>/dev/null | head -20
      ;;
    pdf)
      if command -v pdftotext &>/dev/null; then
        pdftotext "$file" - 2>/dev/null | head -30
      else
        echo "Install poppler-utils for PDF parsing"
      fi
      ;;
    docx|doc)
      if command -v pandoc &>/dev/null; then
        pandoc "$file" -t plain 2>/dev/null | head -30
      else
        echo "Install pandoc for Word document parsing"
      fi
      ;;
    *)
      echo "Unsupported format: .$ext"
      echo "Supported: txt, md, csv, json, pdf, docx"
      ;;
  esac
}

# --- MEETING TRANSCRIPTION ---
ai_transcribe() {
  local audio_file="$1"
  if [ ! -f "$audio_file" ]; then echo "File not found: $audio_file"; return 1; fi
  if command -v whisper &>/dev/null; then
    echo "Transcribing: $audio_file"
    whisper "$audio_file" --language en --output_format txt --output_dir /tmp 2>/dev/null
    local txt="/tmp/$(basename "${audio_file%.*}").txt"
    cat "$txt" 2>/dev/null
  elif command -v ffmpeg &>/dev/null; then
    echo "Audio: $audio_file"
    ffprobe -v quiet -print_format json -show_format "$audio_file" 2>/dev/null | python3 -c "
import json,sys; d=json.load(sys.stdin).get('format',{})
print(f'Duration: {float(d.get(\"duration\",0)):.1f}s')
print('(Install whisper for full transcription: pip install openai-whisper)')
" 2>/dev/null
  else
    echo "No audio tools found. Install ffmpeg + whisper."
  fi
}
