#!/bin/bash
# Enable and disable displays connected to machine using xrandr

enable_only_primary() {
    primary_display=$(xrandr | awk '/ connected primary/ {print $1}')
    secondary_display=$(xrandr | awk '/ connected [^primary]/ {print $1}')
    # enable primary display
    xrandr --output "$primary_display" --auto
    # iterate through all other non-primary displays
    if [[ ! -z "$secondary_display" ]]; then
    for display in "$secondary_display"
        do
            # turn display off
            xrandr --output "$display" --off
        done
    fi
}

case "$1" in
    "-p")
    # enable primary display only
    enable_only_primary
    ;;

    "-s")
    # default to single primary display to clear all other display states out
    enable_only_primary
    # enable first found secondary display only
    primary_display=$(xrandr | awk '/ connected primary/ {print $1}')
    secondary_display=$(xrandr | awk '/ connected [^primary]/ {print $1; exit}')
    if [[ ! -z "$secondary_display" ]]; then
        xrandr --output "$secondary_display" --auto --output "$primary_display" --off
    else
        exit 1
    fi
    ;;

    "-d")
    # scale primary display to first found secondary display
    # default to single primary display to clear all other display states out
    enable_only_primary
    # Set secondary display as scaled duplicate of primary
    primary_res=$(xrandr | awk '/ connected primary/ {print $4}' | cut -d+ -f1)
    duplicate_display=$(xrandr | awk '/ connected [^primary]/ {print $1; exit}')
    if [[ ! -z "$duplicate_display" ]]; then
        xrandr --output "$duplicate_display" --auto --scale-from "$primary_res" 
    else
        exit 1
    fi
    ;;

    "-e")
    # extend display to optimal res of all connected outputs
    # default to single primary display to clear all other display states out
    enable_only_primary
    secondary_display=$(xrandr | awk '/ connected [^primary]/ {print $1}')

    # check to see which direction we want to order the displays in
    if [[ "$2" == "-r" ]]; then
        ordering="--right-of"
    else 
        ordering="--left-of"
    fi

    if [[ ! -z "$secondary_display" ]]; then
        # iterate through all other non-primary displays
        for display in "$secondary_display"
        do
            # turn display on left or right to primary display
            xrandr --output "$display" --auto $ordering $primary_display
        done
    fi
    ;;

    *)
    echo "Usage: xrandr_util.sh <-p | -s | -d | -e [-r]>

Arguments:
    -p      Output to primary monitor only
    -s      Output to secondary monitor only
    -d      Duplicate primary monitor scaled to secondary monitor
    -e      Output and extend to all monitors
    -r      Extend order uses '--right-of' (needs -e)"
    exit 1
    ;;
esac

