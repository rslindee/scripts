#!/bin/bash
trap 'trap - SIGTERM && kill 0' SIGINT SIGTERM EXIT

# TODO: optimize this by grabbing /sys/class/power_supply/BAT0/1 info, but may be different between laptops
get_battery_percent() {
    local total_charge
    local battery_number

    # get charge of all batteries, combine them
    total_charge=$(acpi -b | awk '{print $4}' | grep -Eo "[0-9]+" | paste -sd+ | bc)
    # get amount of batteries in the device
    battery_number=$(acpi -b | wc -l)
    battery_percent=$((total_charge / battery_number))
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
  # TODO: get "disconnected" status
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
    get_date_time
    get_battery_percent
    update_status
  done
}

sound_monitor() {
  while true
  do
    # wait for sound event
    grep --quiet "" <(stdbuf -oL alsactl monitor default)
    get_audio
    update_status
  done
}

ac_monitor() {
  while true
  do
    # wait for acpi ac adapter event
    grep --quiet "ac_adapter"  <(stdbuf -oL acpi_listen)
    get_charging_status
    update_status
  done
}

wifi_monitor() {
  while true
  do
    # wait for wifi event
    grep --quiet "connected" <(stdbuf -oL nmcli --color no --terse device monitor wlp2s0)
    get_wifi_rssi
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

