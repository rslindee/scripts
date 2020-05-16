#!/bin/bash
# Sends all torrents in downloads folder to transmission server and deletes them if successful
# dependencies: transmission-cli
for f in ~/downloads/*.torrent; do
    transmission-remote richnas --add "$f" && rm "$f"
done
