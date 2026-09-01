#!/bin/sh

myname="${0##*/}"

###########
# configs #
###########

# enable tapping
tapping=1

# enable natural scrolling
natscrol=1

# acceleration
accel="-0.050000"

# touchpad transformation matrix
sensitivity_matrix="1.000000, 0.000000, 0.000000, 0.000000, 1.000000, 0.000000, 0.000000, 0.000000, 1.000000"

# always produce output regardless of script being ran from the daemon or a terminal
always_output=""

conf_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/remapd"

#config file
config_file="${conf_dir}/touchpad.rc"

if [ -r "$config_file" ]; then
    . "$config_file"
else
    if [ ! -d "$conf_dir" ]; then
        mkdir -p "$conf_dir"
    fi
    cat << __HEREDOC__ > "$config_file"
# vim: ft=sh
# set touchpad config file

# enable tapping
tapping="$tapping"

# enable natural scrolling
natscrol="$natscrol"

# acceleration
accel="$accel"

# touchpad transformation matrix
sensitivity_matrix="$sensitivity_matrix"

always_output="$always_output"
__HEREDOC__
fi

msgp () {
    type="$1"
    shift
    id="$1"
    shift
    name="$1"
    shift
    act="$1"
    shift
    prop="$1"
    shift
    val="$*"
    if [ -n "$always_output" ] || tty | grep -qF  -e "dev/pts"; then
        printf '[%s] %s: %3s %s - %s: %s "%s"\n' \
            "${myname}" "$type" "$id" "$name" "$act" "$prop" "$val"
    fi 
}

get_touchpads () {
    xinput | awk 'match($0, /**Touchpad/){ gsub(/⎜   ↳ /,"",$0)gsub(/ /,"_",$0)gsub(/__/,"",$0)gsub(/**id=/,"",$0); print $1"::"$2 }'
}

get_dev_prop () {
    xinput list-props "$1" | grep -m1 "$2" | awk -F ':' '{gsub(/\t/, "");gsub(/^[[:space:]]+|[[:space:]]+$/, "");print $2}'
}

dev_set_prop () {
    dev_name="$1"
    dev_id="$2"
    prop="$3"
    value="$4"
    curr_val="$(get_dev_prop "$dev_id" "$prop")"
    if [ "$value" != "$curr_val" ]; then
        # shellcheck disable=2086
        # we DO want word splitting for the values to be applied correctly
        msgp "touchpad" "$dev_id" "$dev_name" "setting" "$prop" "$value"
        xinput set-prop "$dev_id" "$prop" $value
    fi
}

for touchpad in $(get_touchpads) ; do
    touchpad=$(printf '%s' "$touchpad" | sed 's/_/ /g')
    touchpad_id="${touchpad##*::}"
    touchpad_name="${touchpad%%::*}"
    dev_set_prop "$touchpad_name" "$touchpad_id" 'libinput Tapping Enabled' "$tapping"
    dev_set_prop "$touchpad_name" "$touchpad_id" 'libinput Natural Scrolling Enabled' "$natscrol"
    dev_set_prop "$touchpad_name" "$touchpad_id" 'libinput Accel Speed' "$accel"
    dev_set_prop "$touchpad_name" "$touchpad_id" 'Coordinate Transformation Matrix' "$sensitivity_matrix"
done
