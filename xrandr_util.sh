#!/bin/bash
# Enable and disable displays connected to machine using xrandr

enable_only_primary() {
    primary_display=$(xrandr | awk '/ connected primary/ {print $1}')
    secondary_display=$(xrandr | awk '/ connected [^primary]/ {print $1; exit}')
    # enable primary display
    xrandr --output $primary_display --auto
    # iterate through all other non-primary displays
    for display in $secondary_display
    do
        # turn display off
        xrandr --output $display --off
    done

}

case "$1" in
    # enable primary display only
    "-p")
    enable_only_primary
    ;;

    # enable first found secondary display only
    # TODO: disable other secondary displays
    # TODO: bug if secondary display is non-optimal resolution from previous -d, then res wont change. fix this
    "-s")
    target_disable=$(xrandr | awk '/ connected primary/ {print $1}')
    target_enable=$(xrandr | awk '/ connected [^primary]/ {print $1; exit}')
    xrandr --output $target_enable --auto --output $target_disable --off
    ;;

    # scale primary display to first found secondary display
    "-d")
    enable_only_primary
    # Set secondary display as scaled duplicate of primary
    primary_display=$(xrandr | awk '/ connected primary/ {print $1}')
    primary_res=$(xrandr | awk '/ connected primary/ {print $4}' | cut -d+ -f1)
    duplicate_display=$(xrandr | awk '/ connected [^primary]/ {print $1; exit}')
    xrandr --output $duplicate_display --auto --scale-from $primary_res 
    ;;

    *)
    echo "Usage: xrandr_util.sh <-s | -p | -d>"
    exit 1
    ;;
esac

