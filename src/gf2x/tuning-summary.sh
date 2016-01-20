#!/bin/sh

find "$1" -name time |        \
    xargs -n 1 head -1 |        \
    while read a b ; do
        echo "$b [$a]"
    done |                      \
    sort -n > "$2"
