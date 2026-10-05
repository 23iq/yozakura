#!/usr/bin/env sh
# Report processes that hold a V4L2 camera (/dev/video*) open, for the
# privacy live activity (modules/services/activities/CameraWatcher.qml).
#
# Prints one block per change: "<pid> <comm>" lines followed by "--".
# Event driven with inotifywait (open/close on the device nodes); without
# inotify-tools it falls back to a slow poll. Sleeps when no camera exists.

scan() {
    find /proc/[0-9]*/fd -maxdepth 1 -lname '/dev/video*' 2>/dev/null |
        while IFS= read -r fd; do
            pid=${fd#/proc/}
            pid=${pid%%/*}
            comm=$(cat "/proc/$pid/comm" 2>/dev/null) || continue
            echo "$pid $comm"
        done | sort -u
    echo "--"
}

last=""
emit() {
    out=$(scan)
    if [ "$out" != "$last" ]; then
        printf '%s\n' "$out"
        last=$out
    fi
}

has_inotify=0
command -v inotifywait >/dev/null 2>&1 && has_inotify=1

while :; do
    set -- /dev/video*
    if [ ! -e "$1" ]; then
        if [ -n "$last" ] && [ "$last" != "--" ]; then
            echo "--"
            last="--"
        fi
        sleep 30
        continue
    fi
    emit
    if [ "$has_inotify" = 1 ]; then
        # Wakes on the next open/close of any camera; 60s timeout rechecks
        # for hot-plugged devices
        inotifywait -q -q -t 60 -e open -e close "$@" >/dev/null 2>&1
        # Let the opener finish setting up before scanning
        sleep 0.3
    else
        sleep 5
    fi
done
