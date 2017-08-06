#!/bin/sh
# Sorts media files when finished downloading via Transmission
FLAC_DIR=/mnt/hit1/FLAC
NON_FLAC_MP3_DIR=/mnt/hit1/MP3/_Non_FLAC
MKV_DIR=/mnt/red8t/movies
LOG_FILE=/mnt/GREEN1000/download_log.txt
FLAC2MP3_SCRIPT=/mnt/GREEN1000/scripts/flac2mp3.sh
MP3_DIR=/mnt/hit1/MP3
{
    echo "========================================"
    echo "$(date) ---- $TR_TORRENT_NAME finished"
    cd "$TR_TORRENT_DIR"
    # If torrent is dir, enter dir
    if [ -d "$TR_TORRENT_NAME" ]
    then
        # Check for FLAC and copy
        if ls "$TR_TORRENT_NAME"/*.flac > /dev/null 2>&1
        then
            echo "FLAC found"
            cp -av "$TR_TORRENT_NAME" "$FLAC_DIR/_Incoming"
            # Call flac2mp3 script
            "$FLAC2MP3_SCRIPT" "$FLAC_DIR/_Incoming/$TR_TORRENT_NAME" "$FLAC_DIR" "$MP3_DIR"
        elif ls "$TR_TORRENT_NAME"/*.mp3 > /dev/null 2>&1
        then
            echo "MP3 found"
            cp -av "$TR_TORRENT_NAME" "$NON_FLAC_MP3_DIR"
        elif ls "$TR_TORRENT_NAME"/*.mkv > /dev/null 2>&1
        then
            echo "MKV(s) in folder found"
            cp -av "$TR_TORRENT_NAME"/*.mkv "$MKV_DIR"
        fi
    else
        case "${TR_TORRENT_NAME}" in
            *mkv)
                echo "MKV found"
                cp -av "$TR_TORRENT_NAME" "$MKV_DIR" ;;
        esac
    fi
} >> "$LOG_FILE"
