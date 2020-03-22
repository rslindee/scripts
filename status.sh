#!/bin/bash
get_time_remaining() {
    # parses system battery info for the remaining charge of all batteries, sums them up, then divides by the rate at which the batteries are being drained at
    present_rate=0
    sum_remaining_charge=0
    if [ -e /sys/class/power_supply/BAT0 ]; then
        if [ -e /sys/class/power_supply/BAT0/current_now ]; then
            present_rate=$(cat /sys/class/power_supply/BAT0/current_now)
            sum_remaining_charge=$(cat /sys/class/power_supply/BAT0/charge_now)
        else
            present_rate=$(cat /sys/class/power_supply/BAT0/power_now)
            sum_remaining_charge=$(cat /sys/class/power_supply/BAT0/energy_now)
         fi
    fi
    if [ -e /sys/class/power_supply/BAT1 ]; then
        if [ -e /sys/class/power_supply/BAT1/current_now ]; then
            present_rate=$(cat /sys/class/power_supply/BAT1/current_now)
            sum_remaining_charge=$(cat /sys/class/power_supply/BAT1/charge_now)
        else
            present_rate=$(echo "$(cat /sys/class/power_supply/BAT1/power_now)" + "$present_rate" | bc)
            sum_remaining_charge=$(echo "$(cat /sys/class/power_supply/BAT1/energy_now)" + "$sum_remaining_charge" | bc)
        fi
    fi
    # divides current charge by the rate at which it's falling, then converts it into seconds for `date`
    seconds=$(bc <<< "scale = 10; ($sum_remaining_charge / $present_rate) * 3600")
    # prettifies the seconds into hh:mm format
    pretty_time=$(date -u -d @"${seconds}" +%R)

    echo "$pretty_time"
}

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

date="$(date '+%m/%d/%y %H:%M')"

audio="♪: $(amixer sget 'Master' | awk -F"[][]" '/%/ { print $2 " " $(NF-1);exit;}')"
if [ -n "$audio" ]; then
    statusinfo+="$audio"
fi
wifi_ssid="$(nmcli -color no -field type,state,connection dev status | awk '/^wifi.*\ connected/ {print $3}')"
wifi_rssi="$(awk '/^wl/ {print $4}' /proc/net/wireless | cut -d . -f 1)dBm"
if [ -n "$wifi_ssid" ]; then
    statusinfo+="
$wifi_ssid $wifi_rssi"
fi

if [ -e /sys/class/power_supply/BAT0 ]; then
    statusinfo+="
$(get_battery_charging_status) $(get_battery_combined_percent)% $(get_time_remaining)"
fi

notify-send --urgency=low "$date" "$statusinfo"
