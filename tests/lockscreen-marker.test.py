"""The lock survives a shell restart (modules/lockscreen/LockStateMarker.qml).

GlobalStates.lockscreenVisible is mirrored to a marker file: written when the
lock engages, removed when it is released; a shell that starts while the
marker for its display exists locks again. The Process stub records the
marker command and the test runs it for real against a temp runtime dir
(write, remove, permissions, a failing write), then reports the exit code
back; the FileView stub serves what is on disk at load time, either at once
(blockLoading did its job) or only later through `loaded` / `loadFailed`
(the asynchronous variant), and the restore must work both ways.

Covered: a clean first start never locks; lock -> marker (0600, this
display); authenticated or IPC unlock -> marker gone, so a restart does not
lock again (no loop); a restart with the marker locks at once; a marker of
another display or with no runtime dir does nothing; a failed write is
reported loudly and the unlock still removes the marker; a quick
lock/unlock never leaves a marker behind; a failure is not retried in a loop;
a marker of another compositor instance on the same display (a stale one
from a previous login) never locks and is removed; the content arriving
after startup still locks, but never after the user locked/unlocked in
between, and a failed load counts as no marker.
"""
import json
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from lib.waits import settle  # noqa: E402
from PySide6.QtCore import qInstallMessageHandler  # noqa: E402

h = Harness("lockscreen-marker")
h.singleton("Quickshell", "Quickshell", "QtObject { property var vars: ({}); function env(n) { return vars[n] || '' } }")
h.module("Quickshell.Io", {
    # What FileView would read: the test fills it from disk before a load.
    # MarkerDisk.async: text() is empty until deliver(), which emits loaded
    # (or loadFailed for a missing file) like a FileView that loads later.
    "MarkerDisk": "pragma Singleton\nQtObject { property var files: ({}); property bool async: false }",
    "FileView": "QtObject { property string path; property bool blockLoading; property bool printErrors\n"
                " property bool ready: !MarkerDisk.async\n"
                " signal loaded(); signal loadFailed(int error)\n"
                " function text() { return ready ? (MarkerDisk.files[path] || '') : '' }\n"
                " function deliver() { ready = true; if (text() !== '') loaded(); else loadFailed(1) } }",
    "Process": "QtObject { property var command: []; property bool running: false; property int starts: 0\n"
               " onRunningChanged: if (running) starts++\n"
               " signal exited(int exitCode, int exitStatus) }",
})
h.module("qs.modules.globals", {"GlobalStates": "pragma Singleton\nQtObject { property bool lockscreenVisible: false }"})
h.copy("modules/lockscreen/LockStateMarker.qml")

messages: list[str] = []
_prev = qInstallMessageHandler(None)


def _on_message(mode, ctx, msg: str) -> None:
    messages.append(msg)
    if _prev:
        _prev(mode, ctx, msg)


qInstallMessageHandler(_on_message)

runtime = Path(tempfile.mkdtemp(prefix="lock-marker-", dir=h.root))
MARKER = runtime / "yozakura-locked-wayland-1"
ID = "locked display=wayland-1 session=hyprland:abc_1"
HEADER = "import QtQuick\nimport Quickshell\nimport Quickshell.Io\nimport qs.modules.globals\n"


def load(path: Path | str = MARKER, identity: str = ID, asynchronous: bool = False):
    """A fresh shell start: FileView sees the file as it is on disk now
    (asynchronous: only once the test calls reader.deliver())."""
    text = Path(path).read_text() if path and Path(path).exists() else ""
    probe = h.load(HEADER + "QtObject {}")
    h.eval(probe, "MarkerDisk.files = %s; MarkerDisk.async = %s" % (json.dumps({str(path): text}), json.dumps(asynchronous)))
    return h.load(HEADER + 'QtObject { property alias m: m; property LockStateMarker inner: LockStateMarker { id: m; '
                  f'path: {json.dumps(str(path))}; identity: {json.dumps(identity)} }} }}')


def ev(obj, expr):
    return h.eval(obj, expr if expr.startswith("GlobalStates") else "m." + expr)


def command(obj) -> list[str]:
    return json.loads(h.eval(obj, "JSON.stringify(m.writer.command || [])"))


def finish(obj) -> int:
    """Run the pending marker command for real and report its exit code."""
    assert ev(obj, "writer.running"), "a marker command must be pending"
    code = subprocess.run(command(obj), check=False, capture_output=True).returncode
    ev(obj, "writer.running = false")
    ev(obj, f"writer.exited({code}, 0)")
    settle()
    return code


def disable(obj) -> None:
    """The shell instance behind obj is gone: it no longer follows the lock."""
    h.eval(obj, 'm.path = ""')


def set_locked(obj, value: bool) -> None:
    h.eval(obj, f"GlobalStates.lockscreenVisible = {'true' if value else 'false'}")


# 1. Clean first start: no marker, no lock, nothing written.
a = load()
assert not ev(a, "GlobalStates.lockscreenVisible"), "a clean start must not lock"
assert not ev(a, "restored") and ev(a, "writer.starts") == 0, "a clean start touches nothing"

# 2. Lock: the marker is written (private, for this display).
set_locked(a, True)
assert command(a)[:2] == ["sh", "-c"] and command(a)[-2:] == [str(MARKER), ID], command(a)
assert finish(a) == 0
assert MARKER.read_text() == ID + "\n"
assert stat.S_IMODE(MARKER.stat().st_mode) == 0o600, oct(MARKER.stat().st_mode)
assert ev(a, "applied") == "present"

# 3. Unlock (the PAM success path and the IPC unlock both clear the flag).
set_locked(a, False)
assert command(a) == ["rm", "-f", "--", str(MARKER)]
assert finish(a) == 0 and not MARKER.exists(), "unlock removes the marker"

# 4. Restart after a normal unlock: no lock loop.
disable(a)
b = load()
assert not ev(b, "GlobalStates.lockscreenVisible") and not ev(b, "restored")
print("clean start, lock/unlock and restart after unlock passed")

# 5. The shell dies while locked; the restart locks again at once.
set_locked(b, True)
finish(b)
disable(b)
set_locked(b, False)  # the new shell process starts unlocked
assert MARKER.exists()
c = load()
assert ev(c, "GlobalStates.lockscreenVisible"), "a marker for this display locks at startup"
assert ev(c, "restored")
finish(c)  # the restored lock writes its marker again
assert MARKER.read_text() == ID + "\n"
set_locked(c, False)
finish(c)
assert not MARKER.exists(), "unlocking a restored lock removes the marker"
disable(c)
print("restart while locked locks again, and its unlock clears the marker")

# 6. A marker of another session on this display (the compositor died
# while locked, the next login reuses the display and the runtime dir) does
# not lock the new one, and it is removed.
for stale in ("locked display=wayland-1 session=hyprland:old_0", "locked display=wayland-1", "garbage"):
    MARKER.write_text(stale + "\n")
    d = load()
    assert not ev(d, "GlobalStates.lockscreenVisible") and not ev(d, "restored"), stale
    assert command(d) == ["rm", "-f", "--", str(MARKER)], f"{stale!r}: a stale marker is removed"
    finish(d)
    assert not MARKER.exists()
    disable(d)
print("a stale marker of another session never locks and is removed")

# 7. No runtime dir: the marker is off (never /tmp), nothing is written.
e = load(path="")
set_locked(e, True)
assert ev(e, "writer.starts") == 0, "no marker command without a runtime dir"
set_locked(e, False)

# Default path: only under a real XDG_RUNTIME_DIR, via Brand.runtimeFile,
# one file per display, and only with a compositor instance token.
def default_marker(env: dict):
    h.eval(e, "Quickshell.vars = %s" % json.dumps(env))
    obj = h.load(HEADER + "QtObject { property LockStateMarker inner: LockStateMarker {} }")
    got = (h.eval(obj, "inner.path"), h.eval(obj, "inner.identity"))
    h.eval(obj, 'inner.path = ""')
    return got


RUN = {"XDG_RUNTIME_DIR": "/run/user/1000", "WAYLAND_DISPLAY": "wayland-1"}
assert default_marker({})[0] == "", "no XDG_RUNTIME_DIR -> no marker"
assert default_marker(RUN)[0] == "", "no compositor instance token -> no marker"
assert default_marker({**RUN, "HYPRLAND_INSTANCE_SIGNATURE": "abc_1", "WAYLAND_DISPLAY": ""})[0] == "", "no display -> no marker"
path, ident = default_marker({**RUN, "HYPRLAND_INSTANCE_SIGNATURE": "abc_1", "XDG_SESSION_ID": "3"})
assert path.endswith("/yozakura-locked-wayland-1"), path
assert ident == ID, ident
assert default_marker({**RUN, "NIRI_SOCKET": "/run/user/1000/niri.wayland-1.42.sock", "XDG_SESSION_ID": "3"})[1] == \
    "locked display=wayland-1 session=niri:/run/user/1000/niri.wayland-1.42.sock"
assert default_marker({**RUN, "XDG_SESSION_ID": "3"})[1] == "locked display=wayland-1 session=logind:3"
assert default_marker({**RUN, "XDG_SESSION_ID": "3", "WAYLAND_DISPLAY": "/tmp/w/x"})[0].endswith("/yozakura-locked-_tmp_w_x")
h.eval(e, "Quickshell.vars = ({})")
print("other display and missing runtime dir do nothing")

# 8. A failed write is loud, and the unlock still removes the marker.
bad = runtime / "missing-dir" / "yozakura-locked"
f = load(path=bad)
set_locked(f, True)
messages.clear()
assert finish(f) != 0
assert ev(f, "applied") == "unknown"
assert any("could not write the lock marker" in m for m in messages), messages
assert not ev(f, "writer.running"), "a failed write is not retried in a loop"
set_locked(f, False)
assert command(f) == ["rm", "-f", "--", str(bad)], "unlock removes even after a failed write"
assert finish(f) == 0 and ev(f, "applied") == "absent"
disable(f)
print("failed write is reported and unlock still removes")

# 9. Quick lock/unlock: the remove waits for the write and runs after it.
g = load()
set_locked(g, True)
set_locked(g, False)
assert command(g)[:2] == ["sh", "-c"], "the write is still the pending command"
finish(g)
assert MARKER.exists()
assert command(g) == ["rm", "-f", "--", str(MARKER)], "the unlock follows once the write finished"
finish(g)
assert not MARKER.exists(), "a quick lock/unlock leaves no marker"
assert not ev(g, "writer.running")
# ... and lock/unlock/lock ends locked with the marker present.
set_locked(g, True)
set_locked(g, False)
set_locked(g, True)
finish(g)
assert not ev(g, "writer.running"), "nothing left to do: the final state is locked"
assert MARKER.exists()
set_locked(g, False)
finish(g)
assert not MARKER.exists()
print("quick lock/unlock sequences converge")

# 10. The FileView delivers the marker only after startup: the restore
# still happens when the content arrives.
set_locked(g, True)
finish(g)
disable(g)
set_locked(g, False)
assert MARKER.exists()
k = load(asynchronous=True)
assert not ev(k, "GlobalStates.lockscreenVisible") and not ev(k, "decided"), "an empty first read waits"
ev(k, "reader.deliver()")
assert ev(k, "GlobalStates.lockscreenVisible") and ev(k, "restored"), "late content locks again"
finish(k)
set_locked(k, False)
finish(k)
assert not MARKER.exists()
ev(k, "reader.deliver()")
assert not ev(k, "GlobalStates.lockscreenVisible"), "a later load never locks again"
disable(k)

# ... but never after the user locked and unlocked in between.
MARKER.write_text(ID + "\n")
m = load(asynchronous=True)
set_locked(m, True)
finish(m)
set_locked(m, False)
finish(m)
ev(m, "reader.deliver()")
assert not ev(m, "GlobalStates.lockscreenVisible") and not ev(m, "restored"), "no re-lock after a deliberate unlock"
assert not ev(m, "writer.running"), "no lock loop"
disable(m)

# ... and a failed load (missing file) counts as no marker.
n = load(asynchronous=True)
ev(n, "reader.deliver()")
assert ev(n, "decided") and not ev(n, "GlobalStates.lockscreenVisible")
assert ev(n, "writer.starts") == 0
disable(n)

# ... while a stale marker arriving late is removed, not obeyed.
MARKER.write_text("locked display=wayland-1 session=logind:7\n")
q = load(asynchronous=True)
ev(q, "reader.deliver()")
assert not ev(q, "GlobalStates.lockscreenVisible")
assert command(q) == ["rm", "-f", "--", str(MARKER)]
finish(q)
assert not MARKER.exists()
disable(q)
print("late marker content restores once, never after a user lock/unlock")

h.exit(0)
