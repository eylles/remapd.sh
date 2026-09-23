#!/bin/sh

# This script is called to set up and tweak game controllers

# lightbar brightness
# in 0 to 255 range
lightbar=125

# led red color in 0 to 255 range
led_r=125
# led green color in 0 to 255 range
led_g=25
# led blue color in 0 to 255 range
led_b=100

conf_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/remapd"

#config file
config_file="${conf_dir}/gamepads.rc"

if [ -r "$config_file" ]; then
    . "$config_file"
else
    if [ ! -d "$conf_dir" ]; then
        mkdir -p "$conf_dir"
    fi
    cat << __HEREDOC__ > "$config_file"
# vim: ft=sh
# set-gamepad config file

# the values below are used to set the controller
# lightbar brightness and color, altho the script
# only considers sony dualsense controllers and 
# only sets the values if the 'dualsensectl' program
# is present, you can set functions and more variables
# in this file to consider and set other types of
# controllers

# lightbar brightness
# in 0 to 255 range
lightbar=$lightbar

# led red color in 0 to 255 range
led_r=$led_r
# led green color in 0 to 255 range
led_g=$led_g
# led blue color in 0 to 255 range
led_b=$led_b
__HEREDOC__
fi

myname="${0##*/}"
mypid="$$"
# type: int
# description: digit width of the process id number
# default: 6
PIDWIDTH="6"
if [ -r /proc/sys/kernel/pid_max ]; then
        pidmax=$(cat /proc/sys/kernel/pid_max)
        pw=${#pidmax}
fi
if [ -n "$pw" ]; then
    PIDWIDTH="$pw"
fi
PIDWIDTH="$(( PIDWIDTH + 2 ))"
msg() {
    message="$*"
    printf '[%s] %12s %*s: %s\n' \
        "$(date +'%Y-%m-%d %H:%M:%S')" \
        "$myname" \
        "$PIDWIDTH" "$mypid" \
        "$message"

}

dualsense_controller_list () {
    dualsensectl -l | awk 'NR > 1 {print $1}'
}

for_every_dualsense () {
    for controller in $(dualsense_controller_list); do
        dualsensectl -d "$controller" lightbar "$led_r" "$led_g" "$led_b" "$lightbar"
    done
}

msg "applying gamepad settings"
if command -v dualsensectl >/dev/null; then
    milis=$(shuf -i 150-450 -n 1)
    # Give /dev/hidraw creation a split second to finish mounting
    sleep "0.${milis}"
    for_every_dualsense
    set-touchpad
fi
