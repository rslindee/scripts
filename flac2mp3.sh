#!/bin/bash
# Re-encodes FLAC folders to MP3
# dependencies: ffmpeg, flac
FLAC_ALBUM_DIR=$1
FLAC_DIR=$2
MP3_DIR=$3

# Exit prematurely on any failure
set -e

# Gets metadata from FLAC file and populate $ALBUM_FOLDER
get_artist_album ()
{
    ARTIST=$(metaflac --show-tag=ARTIST "$1")
    ARTIST=${ARTIST#*=}
    # Remove forward slahes
    ARTIST=$(sed "s/\//\_/g" <<< "$ARTIST")
    # Convert spaces to underscores
    ARTIST=${ARTIST// /_}
    ALBUM=$(metaflac --show-tag=ALBUM "$1")
    ALBUM=${ALBUM#*=}
    ALBUM=$(sed "s/\//\_/g" <<< "$ALBUM")
    ALBUM=${ALBUM// /_}
}

# If albumartist is null, then copy over artist tag
set_albumartist_if_null ()
{
    ALBUMARTIST=$(metaflac --show-tag=ALBUMARTIST "$1")
    if [ -z "$ALBUMARTIST" ]; then
        TEMP_ARTIST=$(metaflac --show-tag=ARTIST "$1")
        metaflac --set-tag=ALBUMARTIST="$TEMP_ARTIST" "$1"
    fi
}

# Enter FLAC album directory
cd "$FLAC_ALBUM_DIR"

for f in *.flac; do
    set_albumartist_if_null "$f"
done

# Get artist and album name from first FLAC file
for f in *.flac; do
    get_artist_album "$f"
    break
done
# Re-encode FLAC to MP3
for a in *.flac; do
    ffmpeg -i "$a" -qscale:a 0 "${a[@]/%flac/mp3}"
done
# Create directory in MP3 root dir
mkdir -p "$MP3_DIR/$ARTIST/$ALBUM"
# Move MP3 files to album dir in MP3 directory
mv *.mp3 "$MP3_DIR/$ARTIST/$ALBUM"
# Create directory in FLAC root dir
mkdir -p "$FLAC_DIR/$ARTIST/$ALBUM"
# Move remaining flacs and data to new FLAC dir
mv * "$FLAC_DIR/$ARTIST/$ALBUM"
# Delete (now empty) FLAC album folder
rm -rf "$FLAC_ALBUM_DIR"
# TODO SSH and Update MPD library
#mpc update
