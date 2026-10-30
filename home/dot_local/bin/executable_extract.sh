#!/bin/bash

set -e

for f in "$@"; do
  if [ -f "$f" ]; then
    case "$f" in
    *.tar.bz2)   tar -xvjf  "$f"    ;;
    *.tar.gz)    tar -xvzf  "$f"    ;;
    *.tar.xz)    tar -xvJf  "$f"    ;;
    *.bz2)       bunzip2    "$f"    ;;
    *.rar)       rar x      "$f"    ;;
    *.gz)        gunzip     "$f"    ;;
    *.tar)       tar -xvf   "$f"    ;;
    *.tbz2)      tar -xvjf  "$f"    ;;
    *.tgz)       tar -xvzf  "$f"    ;;
    *.zip)       unzip      "$f"    ;;
    *.Z)         uncompress "$f"    ;;
    *.7z)        7z x       "$f"    ;;
    *)           echo "don't know how to extract '$f'..." ;;
    esac
  else
    echo "'$f' is not a valid file!"
  fi
done
