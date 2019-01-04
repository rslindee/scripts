#!/bin/sh
# try https://unix.stackexchange.com/questions/436886/command-to-get-details-on-charge-and-time-remaining-for-two-batteries
# use acpitool
count="$(acpi -b | wc -l)"
sum="$(acpi -b | egrep -o '[0-9]{1,3}%' | tr -d '%' | xargs -I% echo -n '+%')"
battery="Avg capacity: $(( sum / count ))%"

date="$(date '+%m/%d/%y %H:%M')"
wifi_ssid="$(nmcli --colors no device status | awk '/wlp/ {print $4}')"
wifi_rssi="$(cat /proc/net/wireless | awk '/wlp/ {print $4}' | cut -d . -f 1)dBm"
audio="♪: $(amixer sget 'Master' | awk '/Front Left:/ {print $5 " " $6}' | tr -d '[]')"
statusinfo=\
"$wifi_ssid \
$wifi_rssi \
$audio \
$battery"

notify-send "$date" "$statusinfo"
