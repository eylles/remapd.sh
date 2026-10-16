#!/bin/sh

##########
# CONFIG #
##########

# location for demon named pipe and queue files
# default: $XDG_RUNTIME_DIR/remapd
RUN_FILES_LOC="$XDG_RUNTIME_DIR/remapd"

# max minutes an udevadm instance can exist for
# by default 135 minutes
udevadm_instance_lifetime=135

# Type: int
# possible values:
#   0  -  logging disabled
#   1  -  show info messages
#   2  -  show error messages
#   3  -  show debug messages
# -------------------------------------------
# default: 1
LOG_LEVEL=1

conf_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/remapd"

#config file
config_file="${conf_dir}/remapd.rc"

if [ -r "$config_file" ]; then
    . "$config_file"
else
    if [ ! -d "$conf_dir" ]; then
        mkdir -p "$conf_dir"
    fi
    cat << __HEREDOC__ > "$config_file"
# vim: ft=sh
# remapd config file

# default location for pipe and queue files
RUN_FILES_LOC="\$XDG_RUNTIME_DIR/remapd"

# max amount of minuts an udevadm instance may exist for
udevadm_instance_lifetime=$udevadm_instance_lifetime

# daemon log level, this controls the messages shown by the daemon
#   0  -  logging disabled
#   1  -  show info messages
#   2  -  show error messages
#   3  -  show debug messages
# -------------------------------------------
# default: 1
LOG_LEVEL="$LOG_LEVEL"
__HEREDOC__
fi

#############
# CONSTANTS #
#############

# main daemon pid
mypid="$$"
RUNNING=1
myname="${0##*/}"
version="@VERSION@"

export mypid

############
# RUN VARS #
############

# queue file
# default: ${RUN_FILES_LOC}/remapd_${mypid}.queue
QUEUE_FILE="${RUN_FILES_LOC}/remapd_${mypid}.queue"

# pid of running udevmon instance
UDEVMONPID=""

# unix command line compatible booleans

# Type: int
# value: 0
_true=0
# Type: int
# value: 1
_false=1


# usage: is_int "value"
# description: check if passed value is an integer
# return type: retval int boolean
is_int() {
    if [ -n "$1" ]; then
        printf %d "$1" >/dev/null 2>&1
    else
        return "$_false"
    fi
}

u_awk () { awk "$@"; }
if command -v mawk >/dev/null; then
    u_awk () { mawk "$@"; }
fi
if command -v busybox >/dev/null; then
    u_awk () { busybox awk "$@"; }
fi

# usage: pid_tree_search PID NAME
#          PID: the parent pid among whose ps tree we will search
#         NAME: the name of the program whose pid we want
#       return: pid of NAME program
#  return type: stdout integer
# return error: retval _false
pid_tree_search () {
    search_pid="$1"
    search_name="$2"
    word_length="${#search_name}"
    rval=$(
        pstree -Aps "${search_pid}" 2>/dev/null \
        | u_awk \
            -v name="$search_name" \
            -v wlen="$word_length" \
            '\
                BEGIN { search=name"\\([[:digit:]]*\\)" } \
                match( $0, search )\
                {\
                    print substr($0,RSTART+wlen+1,RLENGTH-wlen-2) \
                }\
            '
        )
    if is_int "$rval"; then
        printf '%s\n' "$rval"
    else
        return "$_false"
    fi
}

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
# Return type: void
# Usage: msg "level" "message"
# log level can be:
#     inf
#     err
#     dbg
msg() {
    priority="$1"
    shift
    message="$*"
    should_log=""
    case "$priority" in
      inf)
        if [ "$LOG_LEVEL" -gt 0 ]; then
          should_log="true"
        fi
        ;;
      err)
        if [ "$LOG_LEVEL" -gt 1 ]; then
          should_log="true"
        fi
        ;;
      dbg)
        if [ "$LOG_LEVEL" -gt 2 ]; then
          should_log="true"
        fi
        ;;
    esac
    if [ -n "$should_log" ]; then
        printf '[%s] %12s %*s %s: %s\n' \
            "$(date +'%Y-%m-%d %H:%M:%S')" \
            "$myname" \
            "$PIDWIDTH" "$mypid" \
            "$version" \
            "$message"
    fi

}

clean_udevadm_instances() {
    while pid_tree_search "$mypid" "udevadm" >/dev/null; do
        udevmon_pid=$(pid_tree_search "$mypid" "udevadm")
        if [ -n "$udevmon_pid" ] && kill -0 "$udevmon_pid" 2>/dev/null; then
            kill "$udevmon_pid" 2>/dev/null
            msg "udevadm instance '$udevmon_pid' killed"
        fi
    done
}

cleanup() {
    # Stop background udev monitoring if active
    clean_udevadm_instances

    # Clean IPC assets
    rm -f "$QUEUE_FILE"
    exit 0
}

sig_ignore() {
    :
}

sig_handler() {
    RUNNING=0
}

ipc_handler() {
    if [ -s "$QUEUE_FILE" ]; then
        timestamp=$(date '+%s%3N')
        WORK_FILE="$QUEUE_FILE.${timestamp}.work"
        mv "$QUEUE_FILE" "$WORK_FILE"
        touch "$QUEUE_FILE"
        msg "processing $QUEUE_FILE as $WORK_FILE"

        while read -r ACTION; do
            [ -z "$ACTION" ] && continue
            msg "processing acton: '$ACTION'"
            case "$ACTION" in
                "status")        msg "Daemon is running" ;;
                "remap")         remaps & ;;
                "gamepad")       set-gamepad & ;;
                "touchpad")      set-touchpad & ;;
                "clean udevadm") clean_udevadm_instances ;;
                "stop")          RUNNING=0 ;;
            esac
        done < "$WORK_FILE"
        rm -f "$WORK_FILE"
        sleep 1.225
        clean_udevadm_instances
    fi
}

nudge() {
    kill -USR1 "$mypid" 2>/dev/null
}

udevadm_lifecycle_watchdog() {
    # Keep track of when the stream was kicked off
    launch_time=$(date +%s)
    one_minute=60

    # Run continuously in the background subshell
    while [ "$RUNNING" -eq 1 ]; do
        rnd_secs=$(shuf -i 1-9 -n 1)
        rnd_mili=$(shuf -i 100-950 -n 1)
        secs=$((one_minute + rnd_secs))
        sleep_time="${secs}.${rnd_mili}"
        sleep "$sleep_time"

        # Check if udevadm is actually running before calculation
        if pid_tree_search "$mypid" "udevadm" >/dev/null; then
            current_time=$(date +%s)
            elapsed=$((current_time - launch_time))

            minutes=$udevadm_instance_lifetime
            lifetime_threshold=$((minutes * one_minute))
            if [ "$elapsed" -ge "$lifetime_threshold" ]; then
                echo "clean udevadm" >> "$QUEUE_FILE"
                nudge

                # Reset the baseline clock for the next upcoming cycle
                launch_time=$(date +%s)
            fi
        else
            # If udevadm died or hasn't started yet, reset baseline to current time
            launch_time=$(date +%s)
        fi
    done
}

udevadm_devices_monitoring_stream() {
    msg "starting udevadm instance"
    # Monitor environment blocks and parse in real-time using a shell loop
    udevadm monitor --environment --subsystem=input | {
        is_add=0; is_kbd=0; is_pad=0; is_gamepad=0
        while read -r line; do
            case "$line" in
                ACTION=add)          is_add=1 ;;
                ID_INPUT_KEYBOARD=1) [ "$is_add" -eq 1 ] && is_kbd=$((is_kbd + 1)) ;;
                ID_INPUT_TOUCHPAD=1) [ "$is_add" -eq 1 ] && is_pad=$((is_pad + 1)) ;;
                ID_INPUT_JOYSTICK=1) [ "$is_add" -eq 1 ] && is_gamepad=$((is_gamepad + 1)) ;;
                "")
                    # An empty line signals the end of a hardware uevent block
                    if [ "$is_add" -eq 1 ]; then
                        if [ "$is_kbd" -ge 1 ] || [ "$is_pad" -ge 1 ] || \
                            [ "$is_gamepad" -ge 1 ]; then

                            if [ "$is_kbd" -eq 1 ]; then
                                echo "remap"
                                is_kbd=$((is_kbd + 1))
                            fi
                            if [ "$is_pad" -eq 1 ]; then
                                echo "touchpad"
                                is_pad=$((is_pad + 1))
                            fi
                            if [ "$is_gamepad" -eq 1 ]; then
                                echo "gamepad"
                                is_gamepad=$((is_gamepad + 1))
                            fi

                            nudge
                        fi
                    fi
                    # Reset flags for the next block if this one didn't match
                    is_add=0
                    ;;
            esac
        done
    } >> "$QUEUE_FILE"

}

main() {
    udevadm_lifecycle_watchdog &
    WATCHDOG_PID=$!
    # event loop
    while [ "$RUNNING" -eq 1 ]; do
        UDEVMONPID=$(pid_tree_search "$mypid" "udevadm")
        if [ -z "$UDEVMONPID" ]; then
            udevadm_devices_monitoring_stream &
        fi

        seconds=$(shuf -i 3-7 -n 1)
        milisec=$(shuf -i 100-950 -n 1)
        main_sleep_time="${seconds}.${milisec}"
        sleep "$main_sleep_time"
    done
    if kill -0 "$WATCHDOG_PID" 2>/dev/null; then
        kill "$WATCHDOG_PID" 2>/dev/null
        msg "watcher '$WATCHDOG_PID' killed"
    fi
}

# assign traps
trap sig_handler INT TERM
trap sig_ignore HUP CONT USR2
trap ipc_handler USR1
trap cleanup EXIT

# initialize named pipe
mkdir -p "$RUN_FILES_LOC"
rm -f "$QUEUE_FILE"
touch "$QUEUE_FILE"

msg "Daemon started"

#########################################
##### run tweak scripts immediately #####
#########################################
set-touchpad &
remaps &

main
