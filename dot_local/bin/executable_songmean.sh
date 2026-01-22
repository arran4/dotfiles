#!/bin/bash
xdg-open "https://grok.com/?q=$(playerctl metadata --format '{{ artist }} - {{ title }}. Song lyrics, meaning, context and analysis' -p spotify | sed 's/ /+/g')" # currentsongidentify cursonid songmean
