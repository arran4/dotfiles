#!/usr/bin/env sh
set -e

for src in \
  dot_config/quickshell/assets/bongocat.gif.b64 \
  dot_config/quickshell/assets/kurukuru.gif.b64 \
  dot_config/quickshell/assets/dino.png.b64 \
  dot_config/quickshell/assets/shaders/opacitymask.frag.qsb.b64
 do
  dst="${src%.b64}"
  if [ ! -f "$dst" ]; then
    base64 -d "$src" > "$dst"
  fi
 done
