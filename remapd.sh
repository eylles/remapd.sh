#!/bin/sh

#############
# CONSTANTS #
#############

# main daemon pid
MAIN_PID="$$"
RUNNING=1

##########
# CONFIG #
##########

# location for demon named pipe and queue files
# default: /tmp
RUN_FILES_LOC="/tmp"

# named pipe
# default: ${RUN_FILES_LOC}/remapd_${MAIN_PID}.fifo
PIPE_FILE="${RUN_FILES_LOC}/remapd_${MAIN_PID}.fifo"
# queue file
# default: ${RUN_FILES_LOC}/remapd_${MAIN_PID}.queue
QUEUE_FILE="${RUN_FILES_LOC}/remapd_${MAIN_PID}.queue"

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
RUN_FILES_LOC="$RUN_FILES_LOC"
__HEREDOC__
fi

############
# RUN VARS #
############

# pid of running udevmon instance
UDEVMONPID=""

is_int() {
    if [ -n "$1" ]; then
        printf %d "$1" >/dev/null 2>&1
    else
        return 1
    fi
}

u_awk () { awk "$@"; }
if command -v mawk >/dev/null; then
    u_awk () { mawk "$@"; }
fi

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
    fi
}

cleanup() {
    # Stop background udev monitoring if active
    UDEVMONPID=$(pid_tree_search "$MAIN_PID" "udevadm")
    if [ -n "$UDEVMONPID" ] && kill -0 "$UDEVMONPID" 2>/dev/null; then
        kill "$UDEVMONPID" 2>/dev/null
        echo "[remapd]: udevadm '$UDEVMONPID' killed"
    fi

    # Clean IPC assets
    rm -f "$PIPE_FILE" "$QUEUE_FILE"
    if [ -n "$READER_PID" ]; then
        kill "$READER_PID" 2>/dev/null
        echo "[remapd]: reader '$READER_PID' killed"
    fi
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
        date "+[remapd]: instance $MAIN_PID processing $QUEUE_FILE on %d-%m-%Y %H:%M:%S"
        mv "$QUEUE_FILE" "$QUEUE_FILE.work"
        touch "$QUEUE_FILE"
        
        while read -r ACTION; do
            [ -z "$ACTION" ] && continue
            case "$ACTION" in
                "status")        printf "Daemon is running.\n" ;;
                "remap")         remaps ;;
                "set-touchpad")  set-touchpad ;;
                "stop")          RUNNING=0 ;;
            esac
        done < "$QUEUE_FILE.work"
        rm -f "$QUEUE_FILE.work"
    fi
}

nudge() {
    kill -USR1 "$MAIN_PID" 2>/dev/null
}

# assign traps
trap sig_handler INT TERM
trap sig_ignore HUP CONT USR2
trap ipc_handler USR1
trap cleanup EXIT

# initialize named pipe
rm -f "$PIPE_FILE" "$QUEUE_FILE"
mkfifo -m 600 "$PIPE_FILE"
touch "$QUEUE_FILE"

# Background Reader
(
    while true; do
        if read -r line < "$PIPE_FILE"; then
            if [ -n "$line" ]; then
                printf "%s\n" "$line" >> "$QUEUE_FILE"
                nudge
            fi
        fi
    done
) &
READER_PID=$!

date "+[remapd]: Daemon started %d-%m-%Y %H:%M:%S with PID: $MAIN_PID"

# run tweak scripts immediately
remaps
set-touchpad
# Main Event Loop
while [ "$RUNNING" -eq 1 ]; do
    UDEVMONPID=$(pid_tree_search "$MAIN_PID" "udevadm")
    if [ -z "$UDEVMONPID" ]; then
        (
            # Monitor environment blocks and parse in real-time using a shell loop
            udevadm monitor --environment --subsystem=input | {
                is_add=0; is_kbd=0; is_pad=0
                
                while read -r line; do
                    case "$line" in
                        ACTION=add)          is_add=1 ;;
                        ID_INPUT_KEYBOARD=1) [ "$is_add" -eq 1 ] && is_kbd=1 ;;
                        ID_INPUT_TOUCHPAD=1) [ "$is_add" -eq 1 ] && is_pad=1 ;;
                        "") 
                            # An empty line signals the end of a hardware uevent block
                            if [ "$is_add" -eq 1 ]; then
                                if [ "$is_kbd" -eq 1 ]; then echo "remap"; fi
                                if [ "$is_pad" -eq 1 ]; then echo "set-touchpad"; fi
                                # If we caught a relevant device, break the read loop
                                if [ "$is_kbd" -eq 1 ] || [ "$is_pad" -eq 1 ]; then
                                    break
                                fi
                            fi
                            # Reset flags for the next block if this one didn't match
                            is_add=0; is_kbd=0; is_pad=0
                            ;;
                    esac
                done
            } >> "$QUEUE_FILE"
            # debounce spikes
            milis=$( shuf -i 400-700 -n 1)
            sleep "0.${milis}"
            # Signal the main daemon to flush the queue
            nudge
        ) &
    fi

    # Safe block synchronization check
    wait "$READER_PID" 2>/dev/null
done
