#!/bin/sh -xe

d="${HOME}/Screenshots/mac screenshots"

mkdir "${d}"

defaults write com.apple.screencapture location "${d}"
