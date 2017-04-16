#!/bin/bash
# Re-encodes FLAC folders to MP3
FLAC_DIR=/mnt/hit1/FLAC/_Incoming
MP3_DIR=/mnt/hit1/MP3/
NUM_JOBS=2

ALBUM_FOLDER=
# Gets metadata from FLAC file and populate $ALBUM_FOLDER
function get_album_folder {
    ARTIST="$(metaflac --show-tag=ARTIST "$1")"
    ARTIST=${ARTIST#ARTIST=}
    ALBUM="$(metaflac --show-tag=ALBUM "$1")"
    ALBUM=${ALBUM#ALBUM=}
    ALBUM_FOLDER="$ARTIST"" - ""$ALBUM"
}
# Enter root FLAC incoming directory
cd "$FLAC_DIR"
for d in */ ; do
    # Enter FLAC album dir
    cd "$d"
    # Get ALBUM_FOLDER name from first FLAC file
    for f in *.flac; do
        get_album_folder "$f"
        break
    done
    # Create an album directory in MP3 root dir
    mkdir "$MP3_DIR/$ALBUM_FOLDER"
    # Re-encode FLAC to MP3
    parallel-moreutils -i -j$NUM_JOBS ffmpeg -i {} -qscale:a 0 {}.mp3 -- ./*.flac
    rename .flac.mp3 .mp3 ./*.mp3
    # Move MP3 files to album dir in MP3 directory
    mv *.mp3 "$MP3_DIR/$ALBUM_FOLDER"
    cd "$FLAC_DIR"
    # Move FLAC album folder out of Incoming and into FLAC root folder
    mv "$d" "../$ALBUM_FOLDER"
done
# Update MPD library
mpc update
