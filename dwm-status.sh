#!/bin/bash
trap 'trap - SIGTERM && kill 0' SIGINT SIGTERM EXIT

get_battery_percent() {
  for battery in /sys/class/power_supply/BAT*; do
    if [ -e "$battery"/energy_full ]; then
      battery_capacity=$(< "$battery"/energy_full)
      current_energy=$(< "$battery"/energy_now)
    else
      battery_capacity=$(< "$battery"/charge_full)
      current_energy=$(< "$battery"/charge_now)
    fi
      total_capacity=$((total_capacity + battery_capacity))
      total_energy=$((total_energy + current_energy))
  done
  battery_percent=$((100*total_energy / total_capacity))
  battery_percent+="%"
}

update_status() {
  get_charging_status
  statusinfo="$charger "
  get_battery_percent
  statusinfo+="$battery_percent ┃ "
  get_audio
  statusinfo+="$audio ┃ "
  get_wifi_rssi
  statusinfo+="W: $wifi_rssi ┃ "
  get_date_time
  statusinfo+="$date_time"
  xsetroot -name "$statusinfo"
}

get_charging_status() {
    charger=$(< /sys/class/power_supply/AC/online) 
    if [[ $charger -eq 1 ]]; then
      charger="CHRG"
    else
      charger="BATT"
    fi
}

get_audio() {
  audio="♫: $(amixer sget 'Master' | awk -F"[][]" '/%/ { print $2 " " $(NF-1);exit;}')"
}

get_date_time() {
  date_time="$(date '+%m/%d/%y %H:%M')"
}

get_wifi_rssi() {
  wifi_rssi="$(awk '/^wl/ {print $4}' /proc/net/wireless | cut -d . -f 1)"
  if [[ -z $wifi_rssi ]]; then
    wifi_rssi="off"
  else
    wifi_rssi+="dBm"
  fi
}
# triggers every minute
time_monitor() {
  while true
  do
    sleep $((60 - $(date +%-S)))
    update_status
  done
}

sound_monitor() {
  # wait for sound event
  stdbuf -oL alsactl monitor default | grep --line-buffered 'default' | 
    while read; do 
      update_status
    done
}

ac_monitor() {
  stdbuf -oL acpi_listen | grep --line-buffered 'ac_adapter' | 
    while read; do 
      update_status
    done
}

wifi_monitor() {
  stdbuf -oL nmcli --color no device monitor wlp2s0 | grep --line-buffered 'connected' | 
    while read; do 
      update_status
    done
}

sound_monitor &
ac_monitor &
time_monitor &
wifi_monitor &

update_status
while true
do
  sleep infinity
done

