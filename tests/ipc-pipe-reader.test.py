"""The keybind FIFO reader of GlobalShortcuts.qml exits with its Quickshell.

The reader (`tail -f <runtime>/<app>_ipc.pipe`) used to outlive a restarted
or crashed Quickshell: one leftover tail per restart. It now follows the
Quickshell pid (`tail --pid=$PPID`); this runs the exact script of the QML
under a stand-in parent and checks that commands still arrive, that the
reader is gone shortly after the parent dies (also before any command was
written, while tail would otherwise block in open()), and that a tail
without --pid still reads commands.

The FIFO itself is kept across restarts: a writer that opened it while no
reader ran (a keybind pressed while Quickshell restarts) is released by
the next reader and its command arrives; anything else at the path (a
regular file, a FIFO of another user) is replaced by a fresh 0600 FIFO.

A reader whose Quickshell died before it started (reparented to init or
to a subreaper) exits at once instead of following its new parent.
"""

import ctypes
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
PR_SET_CHILD_SUBREAPER = 36


def reader_script():
    src = QML.read_text()
    m = re.search(
        r'property Process pipeListener: Process \{\s*command: \["sh", "-c", \'([^\']*)\', "ipc-pipe", root\.ipcName, String\(Quickshell\.processId\)\]',
        src,
    )
    assert m, "pipeListener command not found in GlobalShortcuts.qml"
    return m.group(1)


def start(tmp, env_extra=None, out_name="out.txt"):
    """A stand-in Quickshell (sh) that starts the reader and then waits."""
    out = tmp / out_name
    env = dict(os.environ, XDG_RUNTIME_DIR=str(tmp / "rt"))
    env.update(env_extra or {})
    parent = subprocess.Popen(
        ["sh", "-c", 'sh -c "$1" ipc-pipe test_ipc.pipe $$ >"$2" & exec sleep 300', "fakeqs", reader_script(), str(out)],
        env=env,
        start_new_session=True,
    )
    fifo = tmp / "rt" / "test_ipc.pipe"
    deadline = time.monotonic() + 5
    while not fifo.is_fifo():
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


def case(name, fn, env_extra=None, prepare=None):
    tmp = Path(tempfile.mkdtemp(prefix="ipc-pipe-"))
    (tmp / "rt").mkdir()
    if prepare:
        prepare(tmp / "rt" / "test_ipc.pipe")
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


def blocked_writer_released_by_next_reader(parent, fifo, out):
    """The restart window: the reader is gone, a keybind writes, the next
    Quickshell starts its reader on the same FIFO."""
    send(fifo, out, "launcher")
    kill_parent(parent)
    wait_for(lambda: not readers(fifo), "the old reader to exit")
    writer = subprocess.Popen(["sh", "-c", 'echo brightness-up > "$1"', "writer", str(fifo)])
    time.sleep(0.3)
    assert writer.poll() is None, "the writer should block while no reader runs"
    tmp = fifo.parent.parent
    parent2, fifo2, out2 = start(tmp, out_name="out2.txt")
    try:
        assert fifo2 == fifo
        writer.wait(timeout=5)
        wait_for(lambda: "brightness-up" in out2.read_text().splitlines(), "the blocked command to arrive")
        send(fifo, out2, "dashboard")
    finally:
        if writer.poll() is None:
            writer.kill()
            writer.wait()
        kill_parent(parent2)
    wait_for(lambda: not readers(fifo), "the new reader to exit with its parent")


def fresh_private_fifo(parent, fifo, out):
    assert fifo.is_fifo()
    st = fifo.stat()
    assert st.st_uid == os.getuid(), "the FIFO is not ours"
    assert st.st_mode & 0o777 == 0o600, oct(st.st_mode)
    send(fifo, out, "launcher")


def leftover_file(path):
    path.write_text("not a fifo\n")


def foreign_fifo(path):
    os.mkfifo(path, 0o622)
    os.chown(path, 65534, 65534)


def gone(pid):
    try:
        state = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[0]
    except OSError:
        return True
    return state == "Z"


def orphaned_before_start(subreaper, parent_stays=False):
    """The stand-in Quickshell (its pid passed as the reader's $2, as
    Quickshell.processId) forks the reader's sh, which execs the reader
    script only after the stand-in exited: the reader must exit at once
    and leave the FIFO path alone. parent_stays is the control: the same
    start under a live stand-in runs the reader."""
    tmp = Path(tempfile.mkdtemp(prefix="ipc-pipe-"))
    (tmp / "rt").mkdir()
    fifo = tmp / "rt" / "test_ipc.pipe"
    pidfile = tmp / "reader.pid"
    env = dict(os.environ, XDG_RUNTIME_DIR=str(tmp / "rt"))
    libc = ctypes.CDLL(None, use_errno=True)
    if subreaper:
        # orphans come to this (live) process, as to systemd --user
        assert libc.prctl(PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) == 0
    tail = "exec sleep 300" if parent_stays else "exit 0"
    parent = subprocess.Popen(
        [
            "sh",
            "-c",
            'sh -c \'echo $$ >"$3"; sleep 0.3; exec sh -c "$1" ipc-pipe test_ipc.pipe "$2"\' r "$1" $$ "$2" >/dev/null & ' + tail,
            "fakeqs",
            reader_script(),
            str(pidfile),
        ],
        env=env,
        start_new_session=True,
    )
    try:
        if not parent_stays:
            parent.wait()
        wait_for(lambda: pidfile.exists() and pidfile.read_text().strip(), "the reader pid")
        pid = int(pidfile.read_text())
        if parent_stays:
            wait_for(lambda: readers(fifo) == [pid], "the reader to run under a live parent")
            return
        wait_for(lambda: gone(pid), "the orphaned reader to exit", timeout=5)
        if subreaper:
            os.waitpid(pid, 0)
        assert not fifo.exists(), "an orphaned reader created the FIFO"
    finally:
        if parent.poll() is None:
            kill_parent(parent)
        if subreaper:
            libc.prctl(PR_SET_CHILD_SUBREAPER, 0, 0, 0, 0)
        cleanup(fifo)
        shutil.rmtree(tmp, ignore_errors=True)


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
    case("a writer blocked between two readers is released, its command arrives", blocked_writer_released_by_next_reader)
    case("a new FIFO is private", fresh_private_fifo)
    case("a regular file at the path is replaced by a FIFO", fresh_private_fifo, prepare=leftover_file)
    if os.getuid() == 0:
        case("a FIFO of another user is replaced", fresh_private_fifo, prepare=foreign_fifo)
    else:
        print("skip - a FIFO of another user (needs root to chown)")
    orphaned_before_start(subreaper=False, parent_stays=True)
    print("ok - a reader started under its live parent runs")
    orphaned_before_start(subreaper=False)
    print("ok - a reader whose parent died before it started exits (reparented to init)")
    orphaned_before_start(subreaper=True)
    print("ok - a reader whose parent died before it started exits (reparented to a subreaper)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
