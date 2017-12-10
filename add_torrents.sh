#!/bin/bash
# Adds all torrents in given directory to transmission daemon at specified host
TORRENT_DIR=$1
TRANSMISSION_HOST=$2

cd "$TORRENT_DIR"
for f in *.torrent; do
    transmission-remote $TRANSMISSION_HOST --add "$f"
    if [ $? -eq 0 ]; then
        rm "$f"
    fi
done
