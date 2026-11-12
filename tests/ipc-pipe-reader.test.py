"""The keybind FIFO reader of GlobalShortcuts.qml exits with its Quickshell.

The reader (`tail -f <runtime>/<app>_ipc.pipe`) used to outlive a restarted
or crashed Quickshell: one leftover tail per restart. It now follows the
Quickshell pid (`tail --pid=$PPID`); this runs the exact script of the QML
under a stand-in parent and checks that commands still arrive, that the
reader is gone shortly after the parent dies (also before any command was
written, while tail would otherwise block in open()), and that a tail
without --pid still reads commands.
"""

import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QML = ROOT / "modules/services/GlobalShortcuts.qml"


def reader_script():
    src = QML.read_text()
    m = re.search(
        r'property Process pipeListener: Process \{\s*command: \["sh", "-c", \'([^\']*)\', "ipc-pipe", root\.ipcName\]',
        src,
    )
    assert m, "pipeListener command not found in GlobalShortcuts.qml"
    return m.group(1)


def start(tmp, env_extra=None):
    """A stand-in Quickshell (sh) that starts the reader and then waits."""
    out = tmp / "out.txt"
    env = dict(os.environ, XDG_RUNTIME_DIR=str(tmp / "rt"))
    env.update(env_extra or {})
    parent = subprocess.Popen(
        ["sh", "-c", 'sh -c "$1" ipc-pipe test_ipc.pipe >"$2" & exec sleep 300', "fakeqs", reader_script(), str(out)],
        env=env,
        start_new_session=True,
    )
    fifo = tmp / "rt" / "test_ipc.pipe"
    deadline = time.monotonic() + 5
    while not fifo.exists():
        assert time.monotonic() < deadline, "the FIFO never appeared"
        time.sleep(0.02)
    return parent, fifo, out


def readers(fifo):
    """Pids of processes whose argv names the FIFO (the reader)."""
    found = []
    for d in Path("/proc").iterdir():
        if not d.name.isdigit():
            continue
        try:
            argv = (d / "cmdline").read_bytes().split(b"\0")
            state = (d / "stat").read_text().rsplit(")", 1)[1].split()[0]
        except OSError:
            continue
        if state != "Z" and str(fifo).encode() in argv:
            found.append(int(d.name))
    return found


def wait_for(cond, what, timeout=5.0):
    deadline = time.monotonic() + timeout
    while not cond():
        assert time.monotonic() < deadline, f"timed out: {what}"
        time.sleep(0.05)


def send(fifo, out, cmd):
    with open(fifo, "w") as f:
        f.write(cmd + "\n")
    wait_for(lambda: cmd in out.read_text().splitlines(), f"{cmd!r} read")


def kill_parent(parent):
    os.kill(parent.pid, signal.SIGKILL)
    parent.wait()


def cleanup(fifo):
    for pid in readers(fifo):
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass


def case(name, fn, env_extra=None):
    tmp = Path(tempfile.mkdtemp(prefix="ipc-pipe-"))
    (tmp / "rt").mkdir()
    parent, fifo, out = start(tmp, env_extra(tmp) if env_extra else None)
    try:
        wait_for(lambda: readers(fifo), "the reader to start")
        fn(parent, fifo, out)
        print(f"ok - {name}")
    finally:
        if parent.poll() is None:
            kill_parent(parent)
        cleanup(fifo)
        shutil.rmtree(tmp, ignore_errors=True)


def commands_arrive(parent, fifo, out):
    send(fifo, out, "launcher")
    send(fifo, out, "dashboard")


def exits_with_parent_before_any_command(parent, fifo, out):
    time.sleep(0.3)  # the reader is idle, no command ever written
    kill_parent(parent)
    wait_for(lambda: not readers(fifo), "the reader to exit with its parent")


def exits_with_parent_after_commands(parent, fifo, out):
    send(fifo, out, "launcher")
    kill_parent(parent)
    wait_for(lambda: not readers(fifo), "the reader to exit with its parent")


def tail_without_pid(tmp):
    """A PATH where tail rejects --pid (busybox), else the real tail."""
    real = shutil.which("tail")
    bindir = tmp / "bin"
    bindir.mkdir()
    fake = bindir / "tail"
    fake.write_text(
        '#!/bin/sh\nfor a in "$@"; do case "$a" in --pid*) echo "tail: unrecognized option" >&2; exit 1;; esac; done\nexec "$0.real" "$@"\n'
    )
    fake.chmod(0o755)
    (bindir / "tail.real").symlink_to(real)
    return {"PATH": f"{bindir}:{os.environ['PATH']}"}


def main():
    if not shutil.which("tail") or not shutil.which("mkfifo"):
        print("skip - no tail/mkfifo")
        return 0
    case("commands written to the FIFO reach the shell", commands_arrive)
    case("the reader exits with its parent before any command", exits_with_parent_before_any_command)
    case("the reader exits with its parent after commands", exits_with_parent_after_commands)
    case("a tail without --pid still reads commands", commands_arrive, tail_without_pid)
    return 0


if __name__ == "__main__":
    sys.exit(main())
