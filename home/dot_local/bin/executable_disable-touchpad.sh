#!/bin/sh

xinput set-prop "$(xinput list --short | grep 'TouchPad' | sed -re 's/.*id=([0-9]+).*/\1/')" "Device Enabled" 0
