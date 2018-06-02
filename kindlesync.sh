#!/bin/bash
# Converts and syncs books to Kindle device
BOOK_DIR=/mnt/hit1/books
KINDLE_DIR=/misc/kindle/documents

# Exit prematurely on any failure and not use undefined vars
set -eu

# Enter book directory
cd "$BOOK_DIR"

# Convert and delete the original book format
for f in *.epub; do
    pandoc "$f" -o "${f%.epub}.mobi"
    rm "$f"
done

rsync -rltv "$BOOK_DIR" "$KINDLE_DIR"
