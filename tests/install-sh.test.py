#!/usr/bin/env python3
"""install.sh end to end in a sandbox: the compositor choice, the attended
pacman upgrade, non-fatal optional steps and the reboot offer.

Every external command the installer runs (pacman, sudo, systemctl, git, make,
go, curl, dnf, rpm, the built binary, the setup scripts) is a stub on a private
PATH that logs its argv; real tools are only the plain text utilities the
script needs. Nothing touches the system: sudo only logs.
"""

import os
import pty
import re
import select
import shutil
import subprocess
import sys
import tempfile
import threading
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
INSTALL = REPO / "install.sh"
TOOLS = (
    "bash awk sort paste grep sed cat head tail mkdir rm mv install chmod readlink "
    "dirname basename id uname date fold tee sleep mktemp cp find cmp getent ln "
    "touch env tr wc"
).split()

LOGGER = '{ printf "%s" "${0##*/}"; printf "\\t%s" "$@"; printf "\\n"; } >>"$STUB_LOG"\n'

STUBS = {
    "sudo": "exit 0\n",
    "systemctl": 'case "$1" in is-active | is-enabled) exit 1 ;; esac\n',
    "git": 'case "$*" in *--abbrev-ref*) echo main ;; *--short*) echo abc1234 ;; esac\n',
    "make": (
        'if [[ "$1" == -C && "$3" == build ]]; then\n'
        '  for b in yozakura yozd; do cp "$FAKE_BIN" "$2/$b"; chmod 755 "$2/$b"; done\n'
        "fi\n"
    ),
    "go": 'echo "go version go1.24.0 linux/amd64"\n',
    "curl": "exit 22\n",
    "fc-list": "echo Phosphor\n",
    "paru": "exit 0\n",
}
ARCH_STUBS = {
    # -T lists every package as missing; -Qq finds none installed.
    "pacman": 'case "$1" in -T) shift; printf "%s\\n" "$@" ;; -Qq) exit 1 ;; esac\n',
}
FEDORA_STUBS = {
    "rpm": 'shift; for p in "$@"; do echo "package $p is not installed"; done\n',
    "dnf": '[[ "$1" == --version ]] && echo "dnf5 version 5.2"\nexit 0\n',
}
# The built binary: knows install/doctor/version, not --exclusive yet.
FAKE_BIN = "#!/bin/bash\n" + LOGGER + 'case "$1" in version) echo 0.0.0 ;; doctor) echo "doctor: fine" ;; esac\n'
SCRIPTS = {
    # Fails like a voice build without network; knows --vulkan) like Part B's.
    "voice_setup.sh": 'case "$1" in --vulkan) ;; esac\necho "fatal: unable to access github.com" >&2\nexit 1\n',
    "depth_setup.sh": "exit 0\n",
    "install-sddm-theme.sh": "exit 0\n",
}
OS_RELEASE = {
    "arch": 'ID=arch\nPRETTY_NAME="Arch Linux"\n',
    "fedora": 'ID=fedora\nPRETTY_NAME="Fedora Linux 42"\n',
}


class Sandbox:
    def __init__(self, distro="arch"):
        self.root = Path(tempfile.mkdtemp(prefix="install-sh-"))
        self.bin = self.root / "bin"
        self.home = self.root / "home"
        self.src = self.home / ".local/src/yozakura"
        self.log = self.root / "argv.log"
        self.bin.mkdir()
        for tool in TOOLS:
            real = shutil.which(tool)
            assert real, f"missing host tool {tool}"
            (self.bin / tool).symlink_to(real)
        stubs = dict(STUBS, **(ARCH_STUBS if distro == "arch" else FEDORA_STUBS))
        for name, body in stubs.items():
            self._script(self.bin / name, "#!/bin/bash\n" + LOGGER + body)
        self._script(self.root / "fake-yozakura", FAKE_BIN)
        # An existing checkout (sync_repo fetches it; load_deps reads its list).
        (self.src / ".git").mkdir(parents=True)
        (self.src / "version").write_text("0.0.0\n")
        deps = self.src / "backend/pkg/deps"
        deps.mkdir(parents=True)
        shutil.copy(REPO / "backend/pkg/deps/packages.tsv", deps / "packages.tsv")
        for name, body in SCRIPTS.items():
            self._script(self.src / "scripts" / name, "#!/bin/bash\n" + LOGGER + body)
        self.os_release = self.root / "os-release"
        self.os_release.write_text(OS_RELEASE[distro])

    @staticmethod
    def _script(path, body):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body)
        path.chmod(0o755)

    def env(self):
        return {
            "PATH": str(self.bin),
            "HOME": str(self.home),
            "LANG": "C.UTF-8",
            "TERM": "dumb",
            "NO_COLOR": "1",
            "STUB_LOG": str(self.log),
            "FAKE_BIN": str(self.root / "fake-yozakura"),
            "YOZAKURA_OS_RELEASE": str(self.os_release),
            "YOZAKURA_RAW_BASE": "file:///nonexistent",
            "YOZAKURA_GPU": "AMD",
        }

    def run(self, *args, answers=None):
        """Runs install.sh; with answers, on a pseudo-terminal that types them.
        Returns (exit code, stderr, what the terminal showed)."""
        self.log.write_text("")
        err_path = self.root / "stderr"
        shown = []
        with open(err_path, "w") as err:
            if answers is None:
                proc = subprocess.Popen(
                    ["bash", str(INSTALL), *args],
                    env=self.env(),
                    stdin=subprocess.DEVNULL,
                    stdout=err,
                    stderr=err,
                    start_new_session=True,
                )
                rc = proc.wait(timeout=120)
            else:
                rc = self._run_on_tty(args, answers, err, shown)
        return rc, err_path.read_text(), "".join(shown)

    def _run_on_tty(self, args, answers, err, shown):
        """Runs install.sh with a pseudo-terminal as its controlling terminal
        (/dev/tty) and stdout/stderr in err; the terminal output goes to shown.
        The parent keeps the slave open so nothing written is lost on exit."""
        master, slave = pty.openpty()
        name = os.ttyname(slave)
        pid = os.fork()
        if pid == 0:
            os.setsid()
            os.close(os.open(name, os.O_RDWR))  # becomes the controlling tty
            os.dup2(os.open(os.devnull, os.O_RDONLY), 0)
            os.dup2(err.fileno(), 1)
            os.dup2(err.fileno(), 2)
            os.execve("/bin/bash", ["bash", str(INSTALL), *args], self.env())
        os.write(master, answers.encode())
        done = threading.Event()

        def drain():
            while True:
                ready, _, _ = select.select([master], [], [], 0.05)
                if ready:
                    shown.append(os.read(master, 4096).decode(errors="replace"))
                elif done.is_set():
                    return

        reader = threading.Thread(target=drain, daemon=True)
        reader.start()
        rc = os.waitstatus_to_exitcode(os.waitpid(pid, 0)[1])
        done.set()
        reader.join(timeout=5)
        os.close(master)
        os.close(slave)
        return rc

    def calls(self, prog):
        """The logged argv lists of one stub."""
        out = []
        for line in self.log.read_text().splitlines():
            parts = line.split("\t")
            if parts[0] == prog:
                out.append(parts[1:])
        return out

    def cleanup(self):
        shutil.rmtree(self.root, ignore_errors=True)


FAILURES = []


def check(cond, msg, context=""):
    if not cond:
        FAILURES.append(msg)
        print(f"FAIL: {msg}", file=sys.stderr)
        if context:
            print(context[-3000:], file=sys.stderr)


def pacman_upgrades(sb):
    return [c[1:] for c in sb.calls("sudo") if c[:2] == ["pacman", "-Syu"]]


def test_dry_run_niri_plan():
    sb = Sandbox("arch")
    try:
        rc, err, _ = sb.run("--compositor", "niri", "-y", "--no-sddm", "--dry-run")
        check(rc == 0, f"dry run exit {rc}", err)
        for pkg in ("niri", "xwayland-satellite", "xdg-desktop-portal-gnome", "hyprpolkitagent"):
            check(re.search(rf"(?<![\w-]){re.escape(pkg)}(?![\w-])", err), f"niri plan lacks {pkg}", err)
        check(not re.search(r"(?<![\w-])hyprland(?![\w-])", err), "niri plan installs hyprland", err)
        check("xdg-desktop-portal-hyprland" not in err, "niri plan installs the Hyprland portal", err)
        check(".config/niri/config.kdl" in err, "niri plan does not name the niri config", err)
        check("yozakura-sys" in err, "plan does not show the system helper", err)
        check(not pacman_upgrades(sb) and not sb.calls("yozakura"), "dry run changed something", sb.log.read_text())
        check(not (sb.home / ".local/share/yozakura/compositor").exists(), "dry run wrote the compositor file")
    finally:
        sb.cleanup()


def test_fedora_mango_falls_back_and_niri_hint():
    sb = Sandbox("fedora")
    try:
        rc, err, _ = sb.run("--compositor", "mango", "-y", "--no-sddm", "--dry-run")
        check(rc == 0, f"fedora mango dry run exit {rc}", err)
        check("not packaged" in err and "Hyprland" in err, "mango on Fedora does not fall back to Hyprland", err)
        check(re.search(r"(?<![\w-])hyprland(?![\w-])", err), "fallback plan lacks the hyprland package", err)
        rc, err, _ = sb.run("--compositor", "niri", "-y", "--no-sddm", "--dry-run")
        check(rc == 0 and "yalter/niri" in err, "niri on Fedora shows no COPR hint", err)
    finally:
        sb.cleanup()


def test_yes_install_optional_failure_does_not_abort():
    sb = Sandbox("arch")
    try:
        rc, err, _ = sb.run("--compositor", "niri", "-y", "--no-sddm", "--with-voice")
        check(rc == 0, f"install with a failing voice step exit {rc}", err)
        ups = pacman_upgrades(sb)
        check(len(ups) == 1 and "--noconfirm" in ups[0], f"-y upgrade lacks --noconfirm: {ups}")
        installs = [c for c in sb.calls("yozakura") if c[:1] == ["install"]]
        check(["install", "niri"] in installs, f"'yozakura install niri' not run: {installs}")
        check(["install", "hyprland"] not in installs, "Hyprland config installed for niri")
        compositor = sb.home / ".local/share/yozakura/compositor"
        check(compositor.exists() and compositor.read_text().strip() == "niri", "compositor file not written")
        voice = sb.calls("voice_setup.sh")
        check(voice == [["--vulkan"]], f"voice on AMD not built with --vulkan: {voice}")
        check(re.search(r"voice: failed \(see log\)", err), "summary lacks the voice failure", err)
        check(any("doctor" in c for c in sb.calls("yozakura")), "doctor did not run after the failure")
        helper = [c for c in sb.calls("sudo") if c[:1] == ["install"]]
        check(
            helper
            == [
                [
                    "install",
                    "-D",
                    "-o",
                    "root",
                    "-g",
                    "root",
                    "-m",
                    "0755",
                    str(sb.home / ".local/bin/yozakura"),
                    "/usr/local/lib/yozakura/yozakura-sys",
                ]
            ],
            f"system helper not installed root-owned: {helper}",
        )
        check(["reboot"] not in sb.calls("systemctl"), "-y rebooted")
    finally:
        sb.cleanup()


def test_attended_install_menu_and_reboot():
    sb = Sandbox("arch")
    try:
        # Menu: 2 = niri; Proceed: y; Reboot: y.
        rc, err, shown = sb.run("--no-sddm", answers="2\ny\ny\n")
        check(rc == 0, f"attended install exit {rc}", err + shown)
        check("Choose your compositor" in err, "no compositor menu", err)
        ups = pacman_upgrades(sb)
        check(len(ups) == 1 and "--noconfirm" not in ups[0], f"attended upgrade has --noconfirm: {ups}")
        check(["install", "niri"] in sb.calls("yozakura"), "menu choice 2 did not pick niri", sb.log.read_text())
        check("Reboot now to start Yozakura?" in shown, "no reboot question", shown)
        check(["reboot"] in sb.calls("systemctl"), "answered yes but did not reboot", sb.log.read_text())

        # A re-run keeps the compositor and asks neither it nor the reboot.
        rc, err, shown = sb.run("--no-sddm", answers="y\n")
        check(rc == 0, f"re-run exit {rc}", err + shown)
        check("Choose your compositor" not in err, "re-run asked for the compositor again", err)
        check(["install", "niri"] in sb.calls("yozakura"), "re-run lost the configured compositor", sb.log.read_text())
        check("Reboot now" not in shown and ["reboot"] not in sb.calls("systemctl"), "re-run offered a reboot", shown)
    finally:
        sb.cleanup()


def main():
    for test in (
        test_dry_run_niri_plan,
        test_fedora_mango_falls_back_and_niri_hint,
        test_yes_install_optional_failure_does_not_abort,
        test_attended_install_menu_and_reboot,
    ):
        before = len(FAILURES)
        test()
        print(f"{'ok' if len(FAILURES) == before else 'FAIL'}  {test.__name__}")
    if FAILURES:
        sys.exit(1)


if __name__ == "__main__":
    main()
