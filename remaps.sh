#!/bin/sh

# This script is called on startup to remap keys and Increase key speed via a rate change

# keyboard model to use
model="pc105"

# keyboard layouts to use
layouts="us"

# set repeat delay
# this controls ms before repetition
repeat_delay=300
# set key repeat per second
# this controls the repetitions per second
repeats_second=60

# miliseconds a key needs to be pressed before being treated as held
press_ms=150

conf_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/remapd"

#config file
config_file="${conf_dir}/remaps.rc"

if [ -r "$config_file" ]; then
    . "$config_file"
else
    if [ ! -d "$conf_dir" ]; then
        mkdir -p "$conf_dir"
    fi
    cat << __HEREDOC__ > "$config_file"
# vim: ft=sh
# remaps config file

# keyboard model to use
# the 'pc105' is the default model for standar keyboards
model="$model"

# keyboard layouts to use
layouts="$layouts"

# set repeat delay
# this controls ms before repetition
repeat_delay="$repeat_delay"

# set key repeat per second
# this controls the repetitions per second
repeats_second="$repeats_second"

# miliseconds a key needs to be pressed before being treated as held
press_ms="$press_ms"
__HEREDOC__
fi

# set keyboard layouts
setxkbmap -model "$model" -layout "$layouts" -option "" 2>/dev/null
# set repeat rate '$repeats_second' and auto repeat delay '$repeat_delay'ms"
xset r rate "$repeat_delay" "$repeats_second" 2>/dev/null
# Map the caps lock key to super...
setxkbmap -option "caps:super" 2>/dev/null
shift_R=62
# Map shift_R as hyper_r
xmodmap -e "keycode $shift_R = Hyper_R" 2>/dev/null
# Add shift function to hyper
xmodmap -e 'add Shift = Hyper_R' 2>/dev/null
unused_kc=184
# Map caps to an unused keycode according to xmodmap -pke | less
xmodmap -e "keycode $unused_kc = Caps_Lock" 2>/dev/null
# When caps lock is pressed only once, treat it as escape.
# When Shift_R is pressed only once, treat it as caps
killall xcape 2>/dev/null ; xcape -t "$press_ms" -e 'Super_L=Escape;Hyper_R=Caps_Lock' 2>/dev/null
