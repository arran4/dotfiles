#!/bin/bash

if [ -n "$1" ]; then
    FILE=$1
    case $FILE in
    *.tar)
        shift && tar -cf "$FILE" "$@"
        ;;
    *.tar.bz2)
        shift && tar -cjf "$FILE" "$@"
        ;;
    *.tar.xz)
        shift && tar -cJf "$FILE" "$@"
        ;;
    *.tar.gz)
        shift && tar -czf "$FILE" "$@"
        ;;
    *.tgz)
        shift && tar -czf "$FILE" "$@"
        ;;
    *.zip)
        shift && zip "$FILE" "$@"
        ;;
    *.rar)
        shift && rar "$FILE" "$@"
        ;;
    esac
else
    echo "usage: compress <foo.tar.gz> ./foo ./bar"
fi
