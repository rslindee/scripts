#!/bin/sh
UNCRUSTIFY_CFG="uncrustify.cfg"

# get list of staged files
staged_files=$(git diff --name-only --staged | grep -E '\.(c|h|cpp|hpp)$')

if [ -n "$staged_files" ]; then
    uncrustify -c $UNCRUSTIFY_CFG $staged_files --replace --no-backup
fi
