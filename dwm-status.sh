#!/bin/bash
#TODO: sbin workaround?

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
    charger="▲"
  else
    charger="▼"
  fi
}

get_audio() {
  audio="$(amixer sget 'Master')"

  # see if audio is unmuted
  if [[ $audio =~ \[on\] ]]; then
    # grab percentage
    [[ $audio =~ [0-9]+% ]]
    audio="A: ${BASH_REMATCH[0]}"
  else
    audio="A: mute"
  fi
}

get_date_time() {
  date_time="$(date '+%m/%d/%y %H:%M')"
}

get_wifi_rssi() {
  wifi_rssi=$(< /proc/net/wireless)
  # grab first negative number, which corresponds to rssi
  if [[ $wifi_rssi =~ -([0-9]+) ]]; then
    wifi_rssi=${BASH_REMATCH[0]}
    wifi_rssi+="dBm"
  else
    wifi_rssi="off"
  fi
}
# triggers every minute
time_monitor() {
  while true; do
    sleep $((60 - $(date +%-S)))
    update_status
  done
}

sound_monitor() {
  # put in while loop, as alsactl dies during sleep
  while true; do
    # wait for sound event
    stdbuf -oL alsactl monitor default | grep --line-buffered 'default' |
      while read; do
        update_status
      done
  done
}

ac_monitor() {
  # put in while loop, in case acpi_listen gets killed
  while true; do
    stdbuf -oL acpi_listen | grep --line-buffered 'ac_adapter' |
      while read; do
        update_status
      done
  done
}

wifi_monitor() {
  # put in while loop, in case nmcli gets killed
  while true; do
    stdbuf -oL nmcli --color no device monitor wlp2s0 | grep --line-buffered 'connected' |
      while read; do
        update_status
      done
  done
}

sound_monitor &
ac_monitor &
wifi_monitor &

update_status
time_monitor
