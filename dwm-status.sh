#!/bin/bash
# utilities used: amixer pactl nmcli

# add /sbin for fedora compatibility
PATH="$PATH:/sbin"

trap 'trap - SIGTERM && kill 0' SIGINT SIGTERM EXIT

update_status() {
  statusinfo="$charger "
  statusinfo+="$battery_percent ┃ "
  statusinfo+="$audio ┃ "
  statusinfo+="W: $wifi_rssi ┃ "
  statusinfo+="$date_time"
  xsetroot -name "$statusinfo"
}

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

get_charging_status() {
  # TODO: try /sys/class/power_supply/BAT0/status instead?
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
    echo "time" > $pipe
  done
}

sound_monitor() {
  # put in while loop, as alsactl dies during sleep
  while true; do
    # wait for sound event
    grep --quiet "default" <(stdbuf -oL alsactl monitor default)
    # hack to kill alsactl for this specific session, as it gets hung up 
    # for some reason during undocking
    pkill alsactl -x -s 0
    echo "audio" > $pipe
  done
}

ac_monitor() {
  # put in while loop, in case acpi_listen gets killed
  while true; do
    stdbuf -oL acpi_listen | grep --line-buffered 'ac_adapter' |
      while read; do
        echo "charge" > $pipe
      done
  done
}

wifi_monitor() {
  # put in while loop, in case nmcli gets killed
  while true; do
    stdbuf -oL nmcli --color no device monitor wlp2s0 | grep --line-buffered 'connected' |
      while read; do
        echo "wifi" > $pipe
      done
  done
}

# setup fifo named pipe
pipe="/tmp/dwm-status-fifo-$USER"
# TODO: check only current user can read?
if [[ ! -p $pipe ]]; then
  mkfifo $pipe -m600
fi

# start monitors
sound_monitor &
ac_monitor &
wifi_monitor &
time_monitor &

# get first-time values
get_audio
get_wifi_rssi
get_date_time
get_charging_status
get_battery_percent
update_status

while true; do
  if read line <$pipe; then
    if [[ "$line" == audio ]]; then
      get_audio
    elif [[ "$line" == wifi ]]; then
      get_wifi_rssi
    elif [[ "$line" == time ]]; then
      get_date_time
      get_battery_percent
    elif [[ "$line" == charge ]]; then
      get_charging_status
    fi
    update_status
  fi
done
