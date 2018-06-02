#!/bin/bash
# Converts and syncs books to Kindle device
IPOD_DIR=/misc/ipod
MP3_DIR=/mnt/hit1/MP3

export IPOD_MOUNTPOINT=$IPOD_DIR
# Exit prematurely on any failure and not use undefined vars
set -eu

find "$MP3_DIR" -type f -name "*.mp3" | gnupod_addsong.pl -

mktunes.pl
sudo umount /misc/ipod
