#!/bin/sh
awk '
  NR > 2 {
    rx += $2
    tx += $10
  }
  END {
    printf "RX: %.1f MB TX: %.1f MB\n", rx/1024/1024, tx/1024/1024
  }
' /proc/net/dev
