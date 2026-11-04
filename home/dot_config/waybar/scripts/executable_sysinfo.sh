#!/bin/sh
cpu=$(top -bn1 | grep "%Cpu" | awk '{print 100 - $8}')
cpu=$(printf "%.1f" "$cpu")
mem=$(free -m | awk '/^Mem:/ {printf "%.1f", $3/$2*100}')
disk_info=$(df -h / | awk 'NR==2 {printf "%s (%s/%s)", $5, $3, $2}')
printf '{"text":"\uf2db","tooltip":"CPU: %s%%\\nRAM: %s%%\\nDisk: %s"}\n' "$cpu" "$mem" "$disk_info"

