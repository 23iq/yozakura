#!/usr/bin/env bash
# Fake agent CLI for tests: replays a recorded fixture ($FAKECLI_FIXTURE).
#   <        wait for one line on stdin (the adapter's request/answer)
#   =hold    wait until stdin is closed, then exit
#   =exit N  exit with status N
#   # ...    comment
# Every other line is printed to stdout. Received stdin lines are appended
# to $FAKECLI_STDIN_LOG and the argv to $FAKECLI_ARGS_LOG (when set).
set -u
if [ -n "${FAKECLI_ARGS_LOG:-}" ]; then
    printf '%s\n' "$@" >"$FAKECLI_ARGS_LOG"
fi
log="${FAKECLI_STDIN_LOG:-/dev/null}"
exec 3<"$FAKECLI_FIXTURE"
while IFS= read -r line <&3; do
    case "$line" in
    "<")
        IFS= read -r input || exit 0
        printf '%s\n' "$input" >>"$log"
        ;;
    "=hold")
        while IFS= read -r input; do
            printf '%s\n' "$input" >>"$log"
        done
        exit 0
        ;;
    "=exit "*)
        exit "${line#=exit }"
        ;;
    "#"*) ;;
    *) printf '%s\n' "$line" ;;
    esac
done
exit 0
