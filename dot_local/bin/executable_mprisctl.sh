#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   mprisctl playpause
#   mprisctl next
#   mprisctl previous
#   mprisctl pause
#   mprisctl play
#   mprisctl stop
#   mprisctl seek +10
#   mprisctl seek -5
#   mprisctl status
#   mprisctl list
#
# Optional:
#   MPRIS_PLAYER=mpv mprisctl playpause

player="${MPRIS_PLAYER:-}"
cmd="${1:-playpause}"

list_players() {
  busctl --user list | awk '/org\.mpris\.MediaPlayer2\./ {print $1}'
}

pick_player() {
  if [[ -n "$player" ]]; then
    echo "org.mpris.MediaPlayer2.$player"
    return
  fi

  local first
  first="$(list_players | head -n1 || true)"
  if [[ -z "$first" ]]; then
    echo "No MPRIS player found on session bus." >&2
    exit 1
  fi
  echo "$first"
}

get_prop() {
  local bus="$1" iface="$2" prop="$3"
  busctl --user get-property \
    "$bus" \
    /org/mpris/MediaPlayer2 \
    org.freedesktop.DBus.Properties \
    "$iface" \
    "$prop"
}

call_simple() {
  local bus="$1" method="$2"
  busctl --user call \
    "$bus" \
    /org/mpris/MediaPlayer2 \
    org.mpris.MediaPlayer2.Player \
    "$method"
}

call_seek() {
  local bus="$1" seconds="$2"
  local micros
  micros=$(( seconds * 1000000 ))
  busctl --user call \
    "$bus" \
    /org/mpris/MediaPlayer2 \
    org.mpris.MediaPlayer2.Player \
    Seek x "$micros"
}

bus=""

case "$cmd" in
  list)
    list_players
    exit 0
    ;;
  *)
    bus="$(pick_player)"
    ;;
esac

case "$cmd" in
  playpause) call_simple "$bus" PlayPause ;;
  play)      call_simple "$bus" Play ;;
  pause)     call_simple "$bus" Pause ;;
  stop)      call_simple "$bus" Stop ;;
  next)      call_simple "$bus" Next ;;
  previous)  call_simple "$bus" Previous ;;
  seek)
    shift
    secs="${1:-}"
    if [[ -z "$secs" ]]; then
      echo "Usage: mprisctl seek [+|-]SECONDS" >&2
      exit 2
    fi
    call_seek "$bus" "$secs"
    ;;
  status)
    echo "Player: $bus"
    echo -n "PlaybackStatus: "
    get_prop "$bus" org.mpris.MediaPlayer2.Player PlaybackStatus
    echo -n "Metadata: "
    get_prop "$bus" org.mpris.MediaPlayer2.Player Metadata
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    exit 2
    ;;
esac
