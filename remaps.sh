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

# if set to any non empty string function output won't be redirected to dev/null
no_silent_output=""

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

# disable silent output, when set to any non empty value the output of the
# commads used to set the remaps will not be suppressed, useful for debugging
no_silent_output=""
__HEREDOC__
fi

#############
# CONSTANTS #
#############

myname="${0##*/}"
version="@VERSION@"
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
    printf '[%s] %12s %*s %s: %s\n' \
        "$(date +'%Y-%m-%d %H:%M:%S')" \
        "$myname" \
        "$PIDWIDTH" "$mypid" \
        "$version" \
        "$message"

}

get_capsandnums() {
    # xset q | awk '/00: Caps Lock:/ { print "CAPS=" $4 "::""NUMS=" $8 }'
    xset q | awk '/00: Caps Lock:/ { print $4 "::" $8 }'
}

toggle_caps_nums_if_on() {
    capslock_status="$1"
    numslock_status="$2"
    case "$capslock_status" in
        "on")
            xdotool key Caps_Lock
            ;;
    esac
    case "$numslock_status" in
        "on")
            xdotool key Num_Lock
            ;;
    esac
}

set_remaps() {
    CAPSANDNUMS="$(get_capsandnums)"
    CAPS="${CAPSANDNUMS%%::*}"
    NUMS="${CAPSANDNUMS##*::}"
    # toggle off caps lock and nums lock if on to prevent messing with xmodmap
    toggle_caps_nums_if_on "$CAPS" "$NUMS"
    # set keyboard layouts
    setxkbmap -model "$model" -layout "$layouts" -option ""
    # set repeat rate '$repeats_second' and auto repeat delay '$repeat_delay'ms"
    xset r rate "$repeat_delay" "$repeats_second"
    # Map the caps lock key to super...
    setxkbmap -option "caps:super"
    shift_R=62
    # Map shift_R as hyper_r
    xmodmap -e "keycode $shift_R = Hyper_R"
    # Add shift function to hyper
    xmodmap -e 'add Shift = Hyper_R'
    unused_kc=184
    # Map caps to an unused keycode according to xmodmap -pke | less
    xmodmap -e "keycode $unused_kc = Caps_Lock"
    # When caps lock is pressed only once, treat it as escape.
    # When Shift_R is pressed only once, treat it as caps
    killall xcape
    xcape -t "$press_ms" -e 'Super_L=Escape;Hyper_R=Caps_Lock'
    # toggle caps lock and nums lock to restore the previous status if any of them was on
    toggle_caps_nums_if_on "$CAPS" "$NUMS"
}

msg "applying keyboard remaps"

if [ -z "$no_silent_output" ]; then
    set_remaps >/dev/null 2>&1
else
    set_remaps
fi
