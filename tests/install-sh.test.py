#!/usr/bin/env python3
"""install.sh end to end in a sandbox: the compositor choice, the attended
pacman upgrade, non-fatal optional steps and the reboot offer.

Every external command the installer runs (pacman, sudo, systemctl, git, make,
go, curl, dnf, rpm, the built binary, the setup scripts) is a stub on a private
PATH that logs its argv; real tools are only the plain text utilities the
script needs. Nothing touches the system: sudo only logs.
"""

import hashlib
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

LOGGER = '{ printf "%s" "${0##*/}"; [[ $# -eq 0 ]] || printf "\\t%s" "$@"; printf "\\n"; } >>"$STUB_LOG"\n'

STUBS = {
    # STUB_SUDO_DENY: no cached credentials and no password accepted.
    "sudo": '[[ -n "${STUB_SUDO_DENY:-}" ]] && exit 1\nexit 0\n',
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
# The built binary: knows install/doctor/version; --exclusive only with
# FAKE_EXCLUSIVE (Part E builds).
FAKE_BIN = (
    "#!/bin/bash\n"
    + LOGGER
    + 'case "$1" in version) echo 0.0.0 ;; doctor) echo "doctor: fine" ;; esac\n'
    + '[[ "$*" == "install --help" && -n "${FAKE_EXCLUSIVE:-}" ]] && echo "  --exclusive  own the whole config"\n'
    + "exit 0\n"
)
SCRIPTS = {
    # Fails like a voice build without network; knows --vulkan) like Part B's.
    "voice_setup.sh": 'case "$1" in --vulkan) ;; esac\necho "fatal: unable to access github.com" >&2\nexit 1\n',
    "depth_setup.sh": "exit 0\n",
    "install-sddm-theme.sh": "exit 0\n",
}
# --dry-run: every command that could change something writes a marker and
# fails; only the reads the plan needs (pacman -T/-Qq, systemctl
# is-active/is-enabled, go version, curl to stdout) are allowed through.
LOUD = 'printf "%s\\n" "${0##*/} $*" >>"$DRY_MARKER"\nexit 97\n'
DRY_STUBS = {
    name: LOUD
    for name in (
        "sudo pkexec git make paru yay reboot install ln mkdir rm mv cp chmod mktemp touch tee unzip fc-cache makepkg"
    ).split()
}
DRY_STUBS.update(
    {
        "pacman": 'case "$1" in -T) shift; printf "%s\\n" "$@"; exit 0 ;; -Qq) exit 1 ;; esac\n' + LOUD,
        "systemctl": 'case "$1" in is-active | is-enabled) exit 1 ;; esac\n' + LOUD,
        "dnf": '[[ "$1" == --version ]] && { echo "dnf5 version 5.2"; exit 0; }\n' + LOUD,
        "go": '[[ "$1" == version && $# -eq 1 ]] && { echo "go version go1.24.0 linux/amd64"; exit 0; }\n' + LOUD,
        # Reads to stdout only; a file:// URL is served (the package list).
        "curl": (
            'for a in "$@"; do [[ "$a" == -o ]] && { ' + LOUD.replace("\n", "; ", 1) + "}; done\n"
            'u="${*: -1}"; [[ "$u" == file://* ]] && exec cat "${u#file://}"\nexit 22\n'
        ),
    }
)
# The host decides whether the SDDM question comes (detect_system reads the
# real display-manager link; has_systemd the real /run/systemd/system).
ASKS_SDDM = not os.path.islink("/etc/systemd/system/display-manager.service") and os.path.isdir("/run/systemd/system")

OS_RELEASE = {
    "arch": 'ID=arch\nPRETTY_NAME="Arch Linux"\n',
    "fedora": 'ID=fedora\nPRETTY_NAME="Fedora Linux 42"\n',
}


class Sandbox:
    def __init__(self, distro="arch", strict=False):
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
        if strict:
            stubs.update({k: v for k, v in DRY_STUBS.items() if k not in ("pacman", "dnf") or k in stubs})
        for name, body in stubs.items():
            if (self.bin / name).is_symlink():
                (self.bin / name).unlink()
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
        (self.root / "sysbin").mkdir()
        (self.root / "tmp").mkdir()
        self.marker = self.root / "dry-marker"
        self.extra_env = {}

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
            "YOZAKURA_SYS_BIN": str(self.root / "sysbin"),
            "CUDA_PATH": str(self.root / "no-cuda"),
            "TMPDIR": str(self.root / "tmp"),
            "DRY_MARKER": str(self.marker),
            **self.extra_env,
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

    def snapshot(self):
        """Every path under the sandbox (but the run's own logs) with its type,
        mode, mtime and content: two equal snapshots mean nothing changed."""
        out = {}
        for path in sorted(self.root.rglob("*")):
            rel = str(path.relative_to(self.root))
            if rel in ("argv.log", "stderr", "dry-marker"):
                continue
            st = path.lstat()
            if path.is_symlink():
                out[rel] = ("link", os.readlink(path))
            elif path.is_dir():
                out[rel] = ("dir", st.st_mode, st.st_mtime_ns)
            else:
                digest = hashlib.sha256(path.read_bytes()).hexdigest()
                out[rel] = ("file", st.st_mode, st.st_mtime_ns, digest)
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


def test_headless_without_yes_upgrades_noconfirm():
    sb = Sandbox("arch")
    try:
        rc, err, _ = sb.run("--compositor", "niri", "--no-sddm")
        check(rc == 0, f"headless install exit {rc}", err)
        ups = pacman_upgrades(sb)
        check(len(ups) == 1 and "--noconfirm" in ups[0], f"headless upgrade lacks --noconfirm: {ups}")
        check(["reboot"] not in sb.calls("systemctl"), "headless run rebooted")
    finally:
        sb.cleanup()


def test_exclusive_needs_a_binary_that_knows_it():
    sb = Sandbox("arch")
    try:
        rc, err, _ = sb.run("--compositor", "hyprland", "-y", "--no-deps", "--exclusive")
        installs = [c for c in sb.calls("yozakura") if c[:1] == ["install"]]
        check(rc == 0 and "--exclusive skipped" in err, "no skip warning for a binary without --exclusive", err)
        check(["install", "hyprland", "--exclusive"] not in installs, f"--exclusive run anyway: {installs}")
        sb.extra_env["FAKE_EXCLUSIVE"] = "1"
        rc, err, _ = sb.run("--compositor", "hyprland", "-y", "--no-deps", "--exclusive")
        installs = [c for c in sb.calls("yozakura") if c[:1] == ["install"]]
        check(rc == 0 and ["install", "hyprland", "--exclusive"] in installs, f"--exclusive not run: {installs}", err)
    finally:
        sb.cleanup()


def test_fedora_menu_has_no_mango():
    sb = Sandbox("fedora")
    try:
        # Menu: 1; Proceed: n (the dry run would otherwise walk on).
        rc, err, shown = sb.run("--no-sddm", "--dry-run", answers="1\nn\n")
        check(rc == 0 and "Choose your compositor" in err, "no compositor menu on Fedora", err + shown)
        check(not re.search(r"\d\s+Mango", err), "Fedora menu offers Mango", err)
        check("Mango is not listed" in err, "Fedora menu does not say why Mango is missing", err)
        check("[1-2," in shown, "Fedora menu prompt is not 1-2", shown)
        check("asks to confirm" not in err, "Fedora plan says dnf asks to confirm", err)
    finally:
        sb.cleanup()


def test_voice_and_depth_flags_on_nvidia():
    sb = Sandbox("arch")
    try:
        sb.extra_env["YOZAKURA_GPU"] = "NVIDIA"
        rc, err, _ = sb.run("--compositor", "niri", "-y", "--no-deps", "--with-voice", "--with-depth")
        check(rc == 0, f"nvidia install exit {rc}", err)
        check(sb.calls("voice_setup.sh") == [["--cpu"]], f"NVIDIA without nvcc not --cpu: {sb.calls('voice_setup.sh')}")
        check(sb.calls("depth_setup.sh") == [["--gpu"]], f"NVIDIA depth not --gpu: {sb.calls('depth_setup.sh')}")
        cuda = sb.root / "cuda"
        Sandbox._script(cuda / "bin/nvcc", "#!/bin/bash\n")
        sb.extra_env["CUDA_PATH"] = str(cuda)
        sb.run("--compositor", "niri", "-y", "--no-deps", "--with-voice")
        check(sb.calls("voice_setup.sh") == [[]], f"NVIDIA with nvcc not CUDA (no flag): {sb.calls('voice_setup.sh')}")
    finally:
        sb.cleanup()


def test_helper_without_sudo_is_a_warning():
    sb = Sandbox("arch")
    try:
        # Binaries on PATH: nothing else needs sudo; sudo itself refuses.
        sb.extra_env.update(STUB_SUDO_DENY="1", YOZAKURA_BIN_DIR=str(sb.bin))
        rc, err, _ = sb.run("--compositor", "niri", "-y", "--no-deps")
        check(rc == 0, f"install without sudo exit {rc}", err)
        check("sudo cannot run here" in err, "no warning about the missing helper", err)
        check("system helper: failed (see log)" in err, "summary lacks the helper", err)
        check(not [c for c in sb.calls("sudo") if c[:1] == ["install"]], "helper installed without sudo")
        check(["install", "niri"] in sb.calls("yozakura"), "install stopped at the helper", sb.log.read_text())
    finally:
        sb.cleanup()


DRY_ALLOWED = {"pacman", "systemctl", "go", "curl", "fc-list", "rpm", "dnf"}


def check_untouched(sb, before, err):
    check(not sb.marker.exists(), "dry run executed a command", sb.marker.read_text() if sb.marker.exists() else "")
    progs = {line.split("\t")[0] for line in sb.log.read_text().splitlines()}
    check(progs <= DRY_ALLOWED, f"dry run ran {sorted(progs - DRY_ALLOWED)}", sb.log.read_text())
    after = sb.snapshot()
    changed = sorted(k for k in before.keys() | after.keys() if before.get(k) != after.get(k))
    check(not changed, f"dry run changed the sandbox: {changed[:10]}", err)


def test_dry_run_walks_everything_headless():
    sb = Sandbox("arch", strict=True)
    try:
        # A first install: no checkout yet, so the clone is shown too.
        sb.extra_env["YOZAKURA_SRC"] = str(sb.root / "fresh-src")
        raw = sb.root / "raw/backend/pkg/deps"
        raw.mkdir(parents=True)
        shutil.copy(REPO / "backend/pkg/deps/packages.tsv", raw)
        sb.extra_env["YOZAKURA_RAW_BASE"] = "file://" + str(sb.root / "raw")
        before = sb.snapshot()
        rc, err, _ = sb.run(
            "--dry-run", "-y", "--compositor", "hyprland", "--with-voice", "--with-depth", "--with-sddm", "--exclusive"
        )
        check(rc == 0, f"headless dry run exit {rc}", err)
        check_untouched(sb, before, err)
        lines = err.splitlines()
        check(sum("DRY RUN" in line for line in lines) >= 2, "no DRY RUN banner at the top and the bottom", err)
        for want in (
            r"would run: sudo pacman -Syu --needed --noconfirm .*hyprland",
            r"would run: git clone .* " + re.escape(str(sb.root / "fresh-src")),
            r"would run: make -C \S+ build",
            r"would run: install -m 755 ",
            r"would write: ~/\.local/share/yozakura/shell_repo",
            r"would run: sudo install -D -o root -g root -m 0755 .*yozakura-sys",
            r"would write: ~/\.local/share/yozakura/compositor",
            r"would run: \S+/yozakura install hyprland$",
            r"would run: \S+/yozakura install hyprland --exclusive",
            r"would run: bash \S+/voice_setup\.sh",
            r"would run: bash \S+/depth_setup\.sh",
            r"would run: sudo bash \S+/install-sddm-theme\.sh",
            r"would run: \S+/yozakura doctor --with voice,depth,sddm",
            r"yozakura onboarding --dry-run",
        ):
            check(re.search(want, err, re.M), f"dry run does not show {want!r}", err)
        if os.path.isdir("/run/systemd/system"):
            check(re.search(r"would run: sudo systemctl enable", err), "services not shown", err)
        check("would run: systemctl reboot" not in err, "-y dry run offers a reboot", err)
        check("NEEDS ATTENTION" not in err, "dry run reports failures", err)
    finally:
        sb.cleanup()


def test_dry_run_fedora_and_update():
    for distro, args, want in (
        ("fedora", ("--dry-run", "-y", "--compositor", "niri"), r"would run: sudo dnf install -y .*niri"),
        ("arch", ("--update", "--dry-run"), r"would run: make -C \S+ build"),
    ):
        sb = Sandbox(distro, strict=True)
        try:
            before = sb.snapshot()
            rc, err, _ = sb.run(*args)
            check(rc == 0, f"{distro} {args} exit {rc}", err)
            check_untouched(sb, before, err)
            check(re.search(want, err), f"{distro} {args} does not show {want!r}", err)
            check(err.count("DRY RUN") >= 2, f"{distro} {args} lacks the DRY RUN lines", err)
        finally:
            sb.cleanup()


def test_dry_run_interactive_walkthrough():
    sb = Sandbox("arch", strict=True)
    try:
        before = sb.snapshot()
        # Menu: 2 = niri; SDDM (when the host has no login manager): no;
        # Proceed: y; Reboot: y.
        answers = "2\n" + ("n\n" if ASKS_SDDM else "") + "y\ny\n"
        rc, err, shown = sb.run("--dry-run", answers=answers)
        check(rc == 0, f"interactive dry run exit {rc}", err + shown)
        check_untouched(sb, before, err + shown)
        check("Choose your compositor" in err, "no compositor menu", err)
        check(("No login screen found" in shown) == ASKS_SDDM, "SDDM question mismatch", shown)
        check("Proceed?" in shown and "Reboot now to start Yozakura?" in shown, "a question is missing", shown)
        check(
            re.search(r"would run: sudo pacman -Syu --needed (?!.*--noconfirm).*niri", err),
            "attended pacman not shown",
            err,
        )
        check(re.search(r"would run: \S+/yozakura install niri$", err, re.M), "niri config step not shown", err)
        check("would run: systemctl reboot" in err, "reboot not shown", err)
        check("yozakura onboarding --dry-run" in err, "no onboarding dry-run hint", err)
        check("opens by itself" in err, "hint does not say the wizard opens after a reboot", err)
        tail = "\n".join(err.rstrip().splitlines()[-15:])
        check("DRY RUN" in tail, "no closing DRY RUN line", tail)
    finally:
        sb.cleanup()


def main():
    for test in (
        test_dry_run_walks_everything_headless,
        test_dry_run_interactive_walkthrough,
        test_dry_run_fedora_and_update,
        test_headless_without_yes_upgrades_noconfirm,
        test_exclusive_needs_a_binary_that_knows_it,
        test_fedora_menu_has_no_mango,
        test_voice_and_depth_flags_on_nvidia,
        test_helper_without_sudo_is_a_warning,
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
