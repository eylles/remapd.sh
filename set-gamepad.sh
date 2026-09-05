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

dualsense_controller_list () {
    dualsensectl -l | awk 'NR > 1 {print $1}'
}

for_every_dualsense () {
    for controller in $(dualsense_controller_list); do
        dualsensectl -d "$controller" lightbar "$led_r" "$led_g" "$led_b" "$lightbar"
    done
}

if command -v dualsensectl >/dev/null; then
    for_every_dualsense
fi
