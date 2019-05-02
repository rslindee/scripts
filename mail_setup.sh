#!/bin/sh
# Fail right away and prevent use of undefined vars
set -eu

vdirsyncer discover
vdirsyncer metasync
vdirsyncer sync

mkdir -p ~/mail/rslindee-gmail
mkdir -p ~/mail/richard-slindee
mbsync -a -C

systemctl --user enable mbsync.timer
systemctl --user start mbsync.timer
systemctl --user enable vdirsyncer.timer
systemctl --user start vdirsyncer.timer
