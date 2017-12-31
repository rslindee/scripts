#!/bin/sh
# Sorts media files when finished downloading via Deluge
TORRENTID=$1
TORRENTNAME=$2
TORRENTPATH=$3

FLAC_DIR=/mnt/hit1/FLAC
NON_FLAC_MP3_DIR=/mnt/hit1/MP3/_Non_FLAC
MKV_DIR=/mnt/red8t/movies
LOG_FILE=/mnt/3tera/post_download_sort.log
FLAC2MP3_SCRIPT=/mnt/3tera/torrent/scripts/flac2mp3.sh
MP3_DIR=/mnt/hit1/MP3
{
    echo "========================================"
    echo "$(date) ---- $TORRENTNAME finished"
    cd "$TORRENTPATH"
    # If torrent is dir, enter dir
    if [ -d "$TORRENTNAME" ]
    then
        # Check for FLAC and copy
        if ls "$TORRENTNAME"/*.flac > /dev/null 2>&1
        then
            echo "FLAC found"
            cp -av "$TORRENTNAME" "$FLAC_DIR/_Incoming"
            # Call flac2mp3 script
            "$FLAC2MP3_SCRIPT" "$FLAC_DIR/_Incoming/$TORRENTNAME" "$FLAC_DIR" "$MP3_DIR"
        elif ls "$TORRENTNAME"/*.mp3 > /dev/null 2>&1
        then
            echo "MP3 found"
            cp -av "$TORRENTNAME" "$NON_FLAC_MP3_DIR"
        elif ls "$TORRENTNAME"/*.mkv > /dev/null 2>&1
        then
            echo "MKV(s) in folder found"
            cp -av "$TORRENTNAME"/*.mkv "$MKV_DIR"
        fi
    else
        case "${TORRENTNAME}" in
            *mkv)
                echo "MKV found"
                cp -av "$TORRENTNAME" "$MKV_DIR" ;;
        esac
    fi
} >> "$LOG_FILE"
