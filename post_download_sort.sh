#!/bin/sh
# Sorts media files when finished downloading via Transmission

FLAC_DIR=/mnt/5tera/flac
NON_FLAC_MP3_DIR=/mnt/5tera/mp3/_Non_FLAC
MKV_DIR=/mnt/8tera/movies
LOG_FILE=/mnt/3tera/post_download_sort.log
FLAC2MP3_SCRIPT=/mnt/3tera/scripts/flac2mp3.sh
MP3_DIR=/mnt/5tera/mp3
BOOK_DIR=/mnt/5tera/books
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
        elif ls "$TR_TORRENT_NAME"/*.epub > /dev/null 2>&1
        then
            echo "EPUB(s) in folder found"
            cp -av "$TR_TORRENT_NAME"/*.epub "$BOOK_DIR"
        elif ls "$TR_TORRENT_NAME"/*.mobi > /dev/null 2>&1
        then
            echo "MOBI(s) in folder found"
            cp -av "$TR_TORRENT_NAME"/*.mobi "$BOOK_DIR"
        fi
    else
        case "${TR_TORRENT_NAME}" in
            *mkv)
                echo "MKV found"
                cp -av "$TR_TORRENT_NAME" "$MKV_DIR"
                break
                ;;
            *epub)
                echo "EPUB found"
                cp -av "$TR_TORRENT_NAME" "$BOOK_DIR"
                break
                ;;
            *mobi)
                echo "MOBI found"
                cp -av "$TR_TORRENT_NAME" "$BOOK_DIR"
                break
                ;;
            *pdf)
                echo "PDF found"
                cp -av "$TR_TORRENT_NAME" "$BOOK_DIR"
                break
                ;;
            *azw3)
                echo "AZW3 found"
                cp -av "$TR_TORRENT_NAME" "$BOOK_DIR"
                break
                ;;
        esac
    fi
} >> "$LOG_FILE"
