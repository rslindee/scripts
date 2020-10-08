#!/bin/bash
# daemon to fall back on default xrandr "auto" configuration in the even that only one connected display is detected

scan_connected() {
    xrandr_cmd="xrandr"
    num_connected=0
    for output_path in /sys/class/drm/*/status; do
        [ "$(<"$output_path")" = 'connected' ] && num_connected=$((num_connected+1))
        # exit early if we have more than 1 display connected
        if [ "$num_connected" -gt 1 ]; then
            return 0
        fi
    done
    # if we have exactly one display connected, then run xrandr --auto
    if [ "$num_connected" -eq 1 ]; then
        "$xrandr_cmd" --auto
    fi
}

while true; do
    # use udevadm to wait for a monitor remove event
    udevadm monitor --kernel --subsystem-match=drm | grep -q -m 1 "change.*(drm)"
    # TODO: remove events of several monitors at once are pretty pretty quick (~20us), 
    # but I may want to consider adding a short (ms) sleep if fallback isn't 100% accurate
    scan_connected
done
