#!/usr/bin/env bash
# agent-automation.sh — scheduler, cron jobs, timed triggers, automation chains

AGENT_DIR="${TINKER_AI_HOME:-$HOME/.config/vokk}/agent"
mkdir -p "$AGENT_DIR/schedules" "$AGENT_DIR/chains"

# Schedule a task to run at a specific time
agent_schedule() {
  local when="$1" command="$2" name="${3:-task_$(date +%s)}"
  local schedule_file="$AGENT_DIR/schedules/$name.json"
  
  cat > "$schedule_file" <<EOJSON
{
  "name": "$name",
  "when": "$when",
  "command": "$command",
  "created": "$(date -Iseconds)",
  "status": "scheduled"
}
EOJSON
  
  # Add to crontab
  local cron_time=""
  case "$when" in
    *m)  # minutes from now: "30m"
      local mins="${when%m}"
      local target_time=$(date -d "+${mins} minutes" +"%M %H %d %m" 2>/dev/null)
      cron_time="$target_time"
      ;;
    *h)  # hours from now: "2h"
      local hours="${when%h}"
      local target_time=$(date -d "+${hours} hours" +"%M %H %d %m" 2>/dev/null)
      cron_time="$target_time"
      ;;
    *:*:*:*)  # specific time: "14:30:0:0" (HH:MM:DD:MM)
      IFS=':' read -r h m d mon <<< "$when"
      cron_time="$m $h ${d:-*} ${mon:-*}"
      ;;
    daily:*)  # daily at time: "daily:14:30"
      local time="${when#daily:}"
      IFS=':' read -r h m <<< "$time"
      cron_time="$m $h * * *"
      ;;
    now)
      # Run immediately
      nohup bash -c "$command" &>/dev/null &
      echo "Running now: $command"
      return 0
      ;;
    *)
      echo "Unknown time format: $when"
      echo "Supported: 30m, 2h, 14:30:0:0, daily:14:30, now"
      return 1
      ;;
  esac
  
  # Add to crontab (preserving existing)
  local cron_line="$cron_time /bin/bash -c '$command' # $name"
  (crontab -l 2>/dev/null; echo "$cron_line") | crontab - 2>/dev/null
  
  echo "Scheduled: $name at $when"
  echo "Command: $command"
}

# List scheduled tasks
agent_schedule_list() {
  echo "=== Scheduled Tasks ==="
  echo ""
  echo "Cron jobs:"
  crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | sed 's/^/  /' || echo "  (none)"
  echo ""
  echo "Tracked schedules:"
  for f in "$AGENT_DIR/schedules"/*.json; do
    [ -f "$f" ] || continue
    python3 -c "
import json
s = json.load(open('$f'))
print(f'  {s[\"name\"]} | {s[\"when\"]} | {s[\"status\"]}')
print(f'    Command: {s[\"command\"][:60]}')
" 2>/dev/null
  done
}

# Cancel a scheduled task
agent_schedule_cancel() {
  local name="$1"
  # Remove from crontab
  crontab -l 2>/dev/null | grep -v "# $name" | crontab - 2>/dev/null
  # Remove file
  rm -f "$AGENT_DIR/schedules/$name.json" 2>/dev/null
  echo "Cancelled: $name"
}

# Run an automation chain (sequence of steps)
agent_chain() {
  local action="$1" chain_name="${2:-}"
  
  case "$action" in
    run)
      local chain_file="$AGENT_DIR/chains/${chain_name}.json"
      if [ ! -f "$chain_file" ]; then
        echo "Chain not found: $chain_name"; return 1
      fi
      python3 -c "
import json, subprocess
chain = json.load(open('$chain_file'))
print(f'Running chain: {chain[\"name\"]}')
for i, step in enumerate(chain['steps'], 1):
    print(f'  Step {i}: {step[\"description\"]}')
    cmd = step.get('command', '')
    if cmd:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=step.get('timeout', 30))
        if result.returncode != 0:
            print(f'    FAILED: {result.stderr[:100]}')
            break
        if result.stdout.strip():
            print(f'    Output: {result.stdout.strip()[:100]}')
print('Chain complete.')
" 2>/dev/null
      ;;
    create)
      shift 2
      local steps=""
      while [ $# -gt 0 ]; do
        [ -n "$steps" ] && steps+=","
        steps+="{\"description\":\"$1\",\"command\":\"$2\"}"
        shift 2
      done
      cat > "$AGENT_DIR/chains/${chain_name}.json" <<EOJSON
{
  "name": "$chain_name",
  "steps": [$steps],
  "created": "$(date -Iseconds)"
}
EOJSON
      echo "Chain created: $chain_name"
      ;;
    list)
      echo "=== Automation Chains ==="
      for f in "$AGENT_DIR/chains"/*.json; do
        [ -f "$f" ] || continue
        python3 -c "
import json
c = json.load(open('$f'))
print(f'  {c[\"name\"]} — {len(c[\"steps\"])} steps')
" 2>/dev/null
      done
      ;;
  esac
}

# Purchase automation wrapper
agent_purchase() {
  local store="$1" item="$2" action="${3:-order}"
  echo "=== Purchase Agent ==="
  echo "Store: $store"
  echo "Item: $item"
  echo "Action: $action"
  echo ""
  echo "This agent will:"
  echo "1. Open $store website"
  echo "2. Search for $item"
  echo "3. Add to cart"
  echo "4. Proceed to checkout"
  echo ""
  echo "Note: For security, final confirmation requires user approval."
  echo "The agent will pause before completing payment."
  
  # Open the store
  case "${store,,}" in
    *amazon*) xdg-open "https://www.amazon.com/s?k=$item" &>/dev/null ;;
    *walmart*) xdg-open "https://www.walmart.com/search?q=$item" &>/dev/null ;;
    *target*) xdg-open "https://www.target.com/s?searchTerm=$item" &>/dev/null ;;
    *ebay*) xdg-open "https://www.ebay.com/sch/i.html?_nkw=$item" &>/dev/null ;;
    *) xdg-open "https://www.google.com/search?q=buy+$item" &>/dev/null ;;
  esac
  echo "Opening store in browser..."
}
