#!/bin/sh
# TODO battery: "count=$(acpi -b | wc -l); sum=$(acpi -b | egrep -o '[0-9]{1,3}%' | tr -d '%' | xargs -I% echo -n '+%'); echo Avg capacity: $(( sum / count ))%"
date="$(date '+%m/%d/%y %H:%M')"
wifi="$(iwgetid -r) $(cat /proc/net/wireless | awk '/wlp/ {print $4}' | cut -d . -f 1)dBm"
audio="♪: $(amixer sget 'Master' | awk '/Front Left:/ {print $5 " " $6}' | tr -d '[]')"
statusinfo=\
"$wifi
$audio"

notify-send "$date" "$statusinfo"
