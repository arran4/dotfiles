#!/bin/sh
# Simple power menu using wofi or rofi

menu() {
  if command -v wofi >/dev/null 2>&1; then
    wofi --show dmenu --prompt "Power"
  elif command -v rofi >/dev/null 2>&1; then
    rofi -dmenu -p "Power"
  else
    dmenu -p "Power"
  fi
}

choice=$(printf "Shutdown\nReboot\nLock\nSuspend\nLogout\n" | menu)

case "$choice" in
  Shutdown) systemctl poweroff ;;
  Reboot) systemctl reboot ;;
  Lock) command -v swaylock >/dev/null 2>&1 && swaylock ;;
  Suspend) systemctl suspend ;;
  Logout) swaymsg exit ;;
esac

