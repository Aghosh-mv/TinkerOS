#!/bin/bash
# TinkerOS Storage Tuning - I/O scheduler, readahead, writeback, NVMe
case "${1:-status}" in
  status)
    echo "=== Storage Status ==="
    for d in /sys/block/sd* /sys/block/nvme*; do
      [ -d "$d" ] || continue; name=$(basename $d)
      sched=$(cat ${d}/queue/scheduler 2>/dev/null | sed 's/\[//;s/\]//')
      ra=$(cat ${d}/queue/read_ahead_kb 2>/dev/null)
      echo "  $name: scheduler=$sched readahead=${ra}KB"
    done
    echo "  Dirty ratio: $(cat /proc/sys/vm/dirty_ratio) Writeback: $(cat /proc/sys/vm/dirty_expire_centisecs)cs"
    ;;
  scheduler) for d in /sys/block/sd* /sys/block/nvme*; do [ -d "$d" ] && echo ${2:-mq-deadline} | sudo tee ${d}/queue/scheduler > /dev/null 2>&1; done && echo "Scheduler: ${2:-mq-deadline}" ;;
  readahead) for d in /sys/block/sd* /sys/block/nvme*; do [ -d "$d" ] && echo ${2:-256} | sudo tee ${d}/queue/read_ahead_kb > /dev/null 2>&1; done && echo "Readahead: ${2:-256}KB" ;;
  *) echo "Usage: $0 {status|scheduler <name>|readahead <kb>}";;
esac
