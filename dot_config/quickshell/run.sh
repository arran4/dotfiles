#!/usr/bin/env bash

dbus='quickshell.dbus.properties.warning = false;quickshell.dbus.dbusmenu.warning = false'
notifs='quickshell.service.notifications.warning = false'
sni='quickshell.service.sni.host.warning = false'
process='QProcess: Destroyed while process'
cache="Cannot open: file://$XDG_CACHE_HOME/caelestia/imagecache/"

qs -p "$(dirname "${BASH_SOURCE[0]}")" --log-rules "$dbus;$notifs;$sni" | grep -vF -e "$process" -e "$cache"
