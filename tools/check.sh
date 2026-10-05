#!/usr/bin/env bash
# Run every quality gate (or the targets given as arguments) and print a summary.
# Each target is a Makefile target; all run even if an earlier one fails.
# Exit status: 1 if any target failed, 0 otherwise (skipped tools do not fail).
set -u

cd "$(dirname "$0")/.." || exit 2
# Tests must never open windows on the live desktop (see tests/lib/headless.py).
unset WAYLAND_DISPLAY DISPLAY
export QT_QPA_PLATFORM=offscreen
targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
    targets=(parse-qml lint-qml fmt-check lint-go lint-sh lint-py audit test)
fi

declare -A status
declare -A took
log_dir=$(mktemp -d "${TMPDIR:-/tmp}/check.XXXXXX")
trap 'rm -rf "$log_dir"' EXIT

for t in "${targets[@]}"; do
    printf '\n\033[1m== %s\033[0m\n' "$t"
    start=$(date +%s)
    # The audit prints only errors + counts here; `make audit` shows everything.
    make --no-print-directory -s "$t" AUDIT_ARGS=--quiet 2>&1 \
        | grep --line-buffered -v '^make\(\[[0-9]*\]\)\?: \*\*\*' | tee "$log_dir/$t.log"
    rc=${PIPESTATUS[0]}
    took[$t]=$(( $(date +%s) - start ))
    if [ "$rc" -ne 0 ]; then
        status[$t]=FAIL
    elif grep -q '\[skip\]' "$log_dir/$t.log"; then
        status[$t]=SKIP
    else
        status[$t]=ok
    fi
done

printf '\n\033[1m== summary\033[0m\n'
failed=0
for t in "${targets[@]}"; do
    s=${status[$t]}
    case $s in
        FAIL) color=31; failed=1 ;;
        SKIP) color=36 ;;
        *) color=32 ;;
    esac
    note=""
    [ "$s" = SKIP ] && note="  (a tool is missing; see [skip] lines above)"
    printf '  \033[%sm%-5s\033[0m %-10s %3ss%s\n' "$color" "$s" "$t" "${took[$t]}" "$note"
done
if [ "$failed" -ne 0 ]; then
    printf '\n\033[31mcheck FAILED\033[0m\n'
    exit 1
fi
printf '\n\033[32mcheck passed\033[0m\n'
