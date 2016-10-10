#!/bin/bash
# Re-encodes FLAC folders to MP3
FLAC_DIR=/mnt/hit1/FLAC/_Incoming
MP3_DIR=/mnt/hit1/MP3/
# Enter root FLAC incoming directory
cd "$FLAC_DIR"
for d in */ ; do
    # Enter FLAC album dir
    cd "$d"
    # Create an album directory in MP3 root dir
    mkdir "$MP3_DIR/$d"
    # Re-encode FLAC to MP3
    parallel-moreutils -i -j$(nproc) ffmpeg -i {} -qscale:a 0 {}.mp3 -- ./*.flac
    rename .flac.mp3 .mp3 ./*.mp3
    # Move MP3 files to album dir in MP3 directory
    mv *.mp3 "$MP3_DIR/$d"
    cd "$FLAC_DIR"
    # Move FLAC album folder out of Incoming and into FLAC root folder
    mv "$d" ..
done
