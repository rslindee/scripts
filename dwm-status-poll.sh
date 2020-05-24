#!/bin/bash
get_battery_combined_percent() {
    # get charge of all batteries, combine them
    total_charge=$(acpi -b | awk '{print $4}' | grep -Eo "[0-9]+" | paste -sd+ | bc)
    # get amount of batteries in the device
    battery_number=$(acpi -b | wc -l)
    percent=$((total_charge / battery_number))

    echo "$percent"
}

get_battery_charging_status() {
    # acpi can give Unknown or Charging if charging, https://unix.stackexchange.com/questions/203741/lenovo-t440s-battery-status-unknown-but-charging
    acpi -b | grep --quiet Discharging && echo "BATT" || echo "CHRG"
}

while true; do
  statusinfo=
  date="$(date '+%m/%d/%y %H:%M')"
  audio="♪: $(amixer sget 'Master' | awk -F"[][]" '/%/ { print $2 " " $(NF-1);exit;}')"
  if [ -n "$audio" ]; then
      statusinfo+="$audio ┃ "
  fi
  if [ -e /sys/class/power_supply/BAT0 ]; then
      statusinfo+="$(get_battery_charging_status) $(get_battery_combined_percent)% ┃ "
  fi
  wifi_ssid="$(nmcli -color no -field type,state,connection dev status | awk '/^wifi.*'\ connected'/ {print $3}')"
  wifi_rssi="$(awk '/^wl/ {print $4}' /proc/net/wireless | cut -d . -f 1)dBm ┃ "
  if [ -n "$wifi_ssid" ]; then
      statusinfo+="$wifi_ssid $wifi_rssi"
  fi
  statusinfo+="$date"
	xsetroot -name "$statusinfo"
	sleep 2
done
