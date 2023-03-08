#!/bin/bash
# Re-encodes FLAC folders to MP3
# dependencies: ffmpeg, flac
FLAC_INCOMING_ALBUM_DIR=$1
MP3_DIR=$2

# Exit prematurely on any failure
set -e

# Gets metadata from FLAC file and populate $ALBUM_FOLDER
get_artist_album ()
{
    ARTIST=$(metaflac --show-tag=ARTIST "$1" | sed -n 1p)
    ARTIST=${ARTIST#*=}
    # Remove forward slahes
    ARTIST=$(sed "s/\//\_/g" <<< "$ARTIST")
    # Convert spaces to underscores
    ARTIST=${ARTIST// /_}
    ALBUM=$(metaflac --show-tag=ALBUM "$1" | sed -n 1p)
    ALBUM=${ALBUM#*=}
    ALBUM=$(sed "s/\//\_/g" <<< "$ALBUM")
    ALBUM=${ALBUM// /_}
}

# If albumartist is null, then copy over artist tag
set_albumartist_if_null ()
{
    ALBUMARTIST=$(metaflac --show-tag=ALBUMARTIST "$1" | sed -n 1p)
    ALBUMARTIST=${ALBUMARTIST#*=}
    if [ -z "$ALBUMARTIST" ]; then
        TEMP_ARTIST=$(metaflac --show-tag=ARTIST "$1" | sed -n 1p)
        TEMP_ARTIST=${TEMP_ARTIST#*=}
        # metaflac --set-tag=ALBUMARTIST="$TEMP_ARTIST" "$1"
    fi
}

# Enter FLAC album directory
cd "$FLAC_INCOMING_ALBUM_DIR"

# Recursively search for a flac file
FIRST_FILE=$(find . -iname '*.flac' -type f -print -quit)
# If albumartist is null, then copy over artist tag
set_albumartist_if_null "$FIRST_FILE"
# Get artist and album name from first FLAC file
get_artist_album "$FIRST_FILE"
# Re-encode FLAC to MP3
find . -iname '*.flac' -type f -print0 | while IFS= read -r -d '' file
do
    ffmpeg -i "$file" -qscale:a 0 "${file[@]/%flac/mp3}" -nostdin
done
# Create directory in MP3 root dir
mkdir -p "$MP3_DIR/$ARTIST/$ALBUM"
# Move MP3 files to album dir in MP3 directory
find . -iname '*.mp3' -type f -print0 | while IFS= read -r -d '' file
do
  mv "$file" "$MP3_DIR/$ARTIST/$ALBUM"
done
