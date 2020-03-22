#!/bin/bash
# live document preview daemon

EXTENSION="${1##*.}"
BASENAME="${1%%.*}"
OUTDIR="."

if [ "$2" == "-s" ]; then
    PREVIEW=false
else
    PREVIEW=true
fi

case $EXTENSION in
    tex)
        CMD="pdflatex -interaction=nonstopmode $1"
        ;;
    md)
        CMD="pandoc $1 -o $OUTDIR/$BASENAME.htm"
        ;;
    dot)
        CMD="dot -Tpng $1 -o $OUTDIR/$BASENAME.png"
        ;;
    *)
        echo "error: Unrecognized extension"
        exit 1
        ;;
esac

if [ $PREVIEW == true ]; then
    while true; do
        find "$1" | entr -c bash -c "$CMD"
    done
fi
