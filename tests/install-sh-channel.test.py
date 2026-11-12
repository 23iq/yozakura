#!/usr/bin/env python3
"""install.sh update channels: pick_tag against the shared version cases
(tests/fixtures/update-channels.json, also read by the Go and JS tests), the
channel options, and sync_repo / checkout_release / download_release on real
git repositories (a local bare "origin" with stable and beta tags).

The installer's functions are loaded without running main (the last line);
nothing outside the temp dir is touched.
"""

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
INSTALL = REPO / "install.sh"
FIXTURE = json.loads((REPO / "tests" / "fixtures" / "update-channels.json").read_text())
GIT_ENV = {
    "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t",
    "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1",
}
FAILS = []


def check(cond, msg):
    if not cond:
        FAILS.append(msg)
        print("FAIL:", msg)


def git(cwd, *args):
    return subprocess.run(["git", "-C", str(cwd), *args], env={**os.environ, **GIT_ENV},
                          capture_output=True, text=True, check=True).stdout.strip()


def sh(script, home, *args, stdin=""):
    """Runs script after loading install.sh's functions (main is not run)."""
    lib = INSTALL.read_text().rsplit('main "$@"', 1)[0]
    env = {**os.environ, **GIT_ENV, "HOME": str(home), "XDG_CONFIG_HOME": str(home / "config"),
           "XDG_CACHE_HOME": str(home / "cache"), "XDG_DATA_HOME": str(home / "data"), "NO_COLOR": "1"}
    (home / "cache").mkdir(parents=True, exist_ok=True)
    return subprocess.run(["bash", "-c", lib + "\nSPINNER=0\n" + script, "install.sh", *args],
                          input=stdin, env=env, capture_output=True, text=True)


def make_origin(root):
    """origin.git: main with 0.3.0, 0.3.1 (annotated), 0.3.2-beta.1, then one untagged commit."""
    work = root / "work"
    work.mkdir()
    git(work, "init", "-q", "-b", "main")
    for v in ("0.3.0", "0.3.1", "0.3.2-beta.1", "0.3.2-beta.1"):
        (work / "version").write_text(v + "\n")
        git(work, "add", "version")
        git(work, "commit", "-q", "--allow-empty", "-m", v)
    git(work, "tag", "0.3.0", "HEAD~3")
    git(work, "tag", "-a", "-m", "release", "0.3.1", "HEAD~2")
    git(work, "tag", "0.3.2-beta.1", "HEAD~1")
    git(root, "clone", "-q", "--bare", str(work), str(root / "origin.git"))
    return root / "origin.git"


def commit_of(repo, ref):
    return git(repo, "rev-parse", ref + "^{commit}")


def test_pick_tag_fixture(home):
    for case in FIXTURE["select"]:
        for tags in (case["tags"], list(reversed(case["tags"]))):
            r = sh('pick_tag "$1"', home, case["channel"], stdin="\n".join(tags) + ("\n" if tags else ""))
            check(r.returncode == 0, f"pick_tag exit {r.returncode}: {r.stderr}")
            check(r.stdout.strip() == case["want"], f"pick_tag {case['channel']} {tags}: {r.stdout.strip()!r} != {case['want']!r}")
    # every parse case: a version is picked on its own by the beta channel, a non-version never
    for case in FIXTURE["parse"]:
        r = sh('pick_tag beta', home, stdin=case["tag"] + "\n")
        want = case["tag"] if case["version"] is not None else ""
        check(r.stdout.strip() == want, f"pick_tag beta [{case['tag']!r}]: {r.stdout.strip()!r}")
    # compare: the higher of each pair wins (equal pairs: the one without v)
    for a, b, want in FIXTURE["compare"]:
        r = sh('pick_tag beta', home, stdin=f"{a}\n{b}\n")
        if want > 0:
            exp = a
        elif want < 0:
            exp = b
        else:
            exp = a if not a.startswith("v") else b
        check(r.stdout.strip() == exp, f"compare {a} {b}: picked {r.stdout.strip()!r}, want {exp!r}")


def test_options(home):
    r = sh('parse_args --channel nightly', home)
    check(r.returncode != 0 and "Unknown update channel: nightly" in r.stderr, f"bad channel accepted: {r.stderr}")
    r = sh('parse_args --branch dev --channel beta', home)
    check(r.returncode != 0 and "--branch follows a branch" in r.stderr, f"--branch with beta: {r.stderr}")
    r = sh('parse_args --ref 0.3.1', home)
    check(r.returncode != 0 and "--ref needs --channel" in r.stderr, f"--ref alone: {r.stderr}")
    r = sh('parse_args --update --channel beta --ref 0.3.2-beta.1; echo "$CHANNEL $REF $CHANNEL_SET"', home)
    check(r.stdout.strip() == "beta 0.3.2-beta.1 1", f"parsed: {r.stdout!r} {r.stderr}")
    r = sh('parse_args --branch dev; echo "$CHANNEL"', home)
    check(r.stdout.strip() == "git", f"--branch is the git channel: {r.stdout!r}")
    r = sh('usage', home)
    check("--channel NAME" in r.stdout and "--ref TAG" in r.stdout, "usage lacks --channel / --ref")


def test_resolve_channel(home, root):
    src = root / "nothing-here"
    r = sh(f'SRC_DIR={src}; resolve_channel; echo "[$CHANNEL]"', home)
    check(r.stdout.strip() == "[]", f"a first install without a setting follows main: {r.stdout!r}")
    r = sh(f'SRC_DIR={root}; resolve_channel; echo "[$CHANNEL]"', home)
    check(r.stdout.strip() == "[stable]", f"an existing install defaults to stable: {r.stdout!r}")
    cfg = home / "config" / "yozakura" / "config"
    cfg.mkdir(parents=True, exist_ok=True)
    (cfg / "system.json").write_text('{\n    "language": "auto",\n    "updateChannel": "beta"\n}\n')
    r = sh(f'SRC_DIR={src}; resolve_channel; echo "[$CHANNEL]"', home)
    check(r.stdout.strip() == "[beta]", f"the saved channel: {r.stdout!r}")
    r = sh(f'SRC_DIR={src}; CHANNEL=git; resolve_channel; echo "[$CHANNEL]"', home)
    check(r.stdout.strip() == "[git]", f"--channel wins: {r.stdout!r}")
    (cfg / "system.json").write_text('{"updateChannel": "nightly"}')
    r = sh(f'SRC_DIR={root}; resolve_channel; echo "[$CHANNEL]"', home)
    check(r.stdout.strip() == "[stable]", f"an invalid saved channel is ignored: {r.stdout!r}")
    (cfg / "system.json").unlink()


def sync(home, src, origin, channel, ref="", extra=""):
    return sh(f'REPO_URL={origin}; SRC_DIR={src}; CHANNEL={channel}; REF={ref}; LOG_FILE={home}/cache/install.log\n'
              f'{extra}\nsync_repo; echo "RELEASE_TAG=$RELEASE_TAG"', home)


def test_sync_repo(home, root):
    origin = make_origin(root)
    src = root / "src"
    git(root, "clone", "-q", str(origin), str(src))
    tip = commit_of(src, "HEAD")

    # main past the newest release: stable and beta keep it, nothing rewinds
    for ch in ("stable", "beta"):
        r = sync(home, src, origin, ch)
        check(r.returncode == 0, f"{ch} from main tip exit {r.returncode}: {r.stderr}")
        check(commit_of(src, "HEAD") == tip, f"{ch} rewound main")
        check("at or past" in r.stderr, f"{ch}: no 'at or past' note: {r.stderr}")
        check(git(src, "rev-parse", "--abbrev-ref", "HEAD") == "main", f"{ch} left main")

    # an explicit --ref (yozakura update decided, e.g. --allow-downgrade) moves
    r = sync(home, src, origin, "stable", "0.3.1")
    check(commit_of(src, "HEAD") == commit_of(src, "0.3.1"), f"--ref 0.3.1 not checked out: {r.stderr}")
    check("RELEASE_TAG=0.3.1" in r.stdout, f"RELEASE_TAG: {r.stdout}")

    # from 0.3.1 the beta channel moves forward on its own
    r = sync(home, src, origin, "beta")
    check(commit_of(src, "HEAD") == commit_of(src, "0.3.2-beta.1"), f"beta did not move forward: {r.stderr}")
    check("Sources at 0.3.2-beta.1 (beta channel)" in r.stderr, f"beta message: {r.stderr}")

    # a new stable release on origin: a beta user follows it
    other = root / "other"
    git(root, "clone", "-q", str(origin), str(other))
    (other / "version").write_text("0.3.2\n")
    git(other, "commit", "-q", "-am", "0.3.2")
    git(other, "tag", "0.3.2")
    git(other, "push", "-q", "origin", "main", "0.3.2")
    r = sync(home, src, origin, "beta")
    check(commit_of(src, "HEAD") == commit_of(src, "0.3.2"), f"beta stuck behind stable: {r.stderr}")
    check("RELEASE_TAG=0.3.2" in r.stdout, f"RELEASE_TAG after the stable release: {r.stdout}")

    # local changes are kept (no reset), on a tag channel too
    r = sync(home, src, origin, "stable", "0.3.1")
    check(commit_of(src, "HEAD") == commit_of(src, "0.3.1"), "--ref 0.3.1 again")
    (src / "version").write_text("mine\n")
    r = sync(home, src, origin, "beta")
    check(commit_of(src, "HEAD") == commit_of(src, "0.3.1"), "a dirty checkout was moved")
    check((src / "version").read_text() == "mine\n", "local changes lost")
    check("local changes" in r.stderr, f"no local-changes warning: {r.stderr}")
    git(src, "checkout", "-q", "--", "version")

    # git channel from a release checkout: back on main, at the tip
    r = sync(home, src, origin, "git")
    check(r.returncode == 0, f"git exit {r.returncode}: {r.stderr}")
    check(git(src, "rev-parse", "--abbrev-ref", "HEAD") == "main", f"git did not return to main: {r.stderr}")
    check(commit_of(src, "HEAD") == commit_of(origin, "main"), f"git not at the tip of main: {r.stderr}")

    # a fresh clone on a tag channel starts at the release
    fresh = root / "fresh"
    r = sync(home, fresh, origin, "stable")
    check(r.returncode == 0, f"fresh clone exit {r.returncode}: {r.stderr}")
    check(commit_of(fresh, "HEAD") == commit_of(fresh, "0.3.2"), f"fresh stable clone not at 0.3.2: {r.stderr}")
    # and without a channel (first install, no setting): main, as before
    legacy = root / "legacy"
    r = sync(home, legacy, origin, "")
    check(git(legacy, "rev-parse", "--abbrev-ref", "HEAD") == "main", f"first install left main: {r.stderr}")

    # dry run: nothing moves, the step is described
    before = commit_of(src, "HEAD")
    r = sh(f'REPO_URL={origin}; SRC_DIR={src}; CHANNEL=stable; DRY_RUN=1; LOG_FILE={home}/cache/install.log\nsync_repo', home)
    check(commit_of(src, "HEAD") == before, "dry run moved the checkout")
    check("would run: git -C" in r.stderr and "checkout -q --detach" in r.stderr, f"dry run note: {r.stderr}")


def test_download_release_url(home, root):
    script = ('curl() { printf "%s\\n" "$*" >>"$CALLS"; return 22; }\n'
              f'REPO_URL=https://example.invalid/o/r.git; SRC_DIR={root}\n'
              'RELEASE_TAG=0.3.2-beta.1; download_release || true\nRELEASE_TAG=; download_release || true\n')
    calls = root / "curl-calls"
    lib_env = f"CALLS={calls}\n"
    sh(lib_env + script, home)
    lines = calls.read_text().splitlines() if calls.exists() else []
    check(any("https://example.invalid/o/r/releases/download/0.3.2-beta.1/SHA256SUMS" in x for x in lines),
          f"tag channel does not download its release: {lines}")
    check(any("https://example.invalid/o/r/releases/latest/download/SHA256SUMS" in x for x in lines),
          f"no tag: not the latest release: {lines}")


def test_save_channel(home, root):
    calls = root / "bin-calls"
    fake = root / "bin"
    fake.mkdir()
    (fake / "yozakura").write_text(f'#!/bin/sh\necho "$*" >>{calls}\n')
    (fake / "yozakura").chmod(0o755)
    base = f'BIN_DIR={fake}; LOG_FILE={home}/cache/install.log\n'
    sh(base + 'CHANNEL=beta CHANNEL_SET=1 UPDATE_ONLY=0 save_channel', home)
    sh(base + 'CHANNEL=git CHANNEL_SET=1 UPDATE_ONLY=1 save_channel', home)
    sh(base + 'CHANNEL=stable CHANNEL_SET=0 UPDATE_ONLY=0 save_channel', home)
    got = calls.read_text().splitlines() if calls.exists() else []
    check(got == ["config set system.updateChannel beta"], f"save_channel calls: {got}")


def main():
    if subprocess.run(["git", "--version"], capture_output=True).returncode != 0:
        print("SKIP: git not installed")
        return 0
    tests = [test_pick_tag_fixture, test_options, test_resolve_channel, test_sync_repo,
             test_download_release_url, test_save_channel]
    for t in tests:
        with tempfile.TemporaryDirectory(prefix="install-ch-") as d:
            root = Path(d)
            home = root / "home"
            home.mkdir()
            before = len(FAILS)
            if t.__code__.co_argcount == 1:
                t(home)
            else:
                t(home, root)
            print(("ok  " if len(FAILS) == before else "FAIL") + " " + t.__name__)
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
