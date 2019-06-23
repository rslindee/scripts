#!/bin/bash
# Converts and syncs books to Kindle device
BOOK_DIR=/mnt/5tera/books/
KINDLE_DIR=/run/media/rich/Kindle

# Exit prematurely on any failure and not use undefined vars
set -eu

# Enter book directory
cd "$BOOK_DIR"

# Convert and delete the original book format
if ls *.epub >/dev/null 2>&1; then
    for f in *.epub; do
        pandoc "$f" -o "${f%.epub}.mobi"
        rm "$f"
    done
fi

rsync -rltv "$BOOK_DIR" "$KINDLE_DIR/documents"

until sudo umount "$KINDLE_DIR"
do
    echo "Retrying umount of kindle in 1s..."
    sleep 1
done
