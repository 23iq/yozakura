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
    """origin.git: main with 0.4.0, 0.4.1 (annotated), 0.4.2-beta.1, then one untagged commit."""
    work = root / "work"
    work.mkdir()
    git(work, "init", "-q", "-b", "main")
    for v in ("0.4.0", "0.4.1", "0.4.2-beta.1", "0.4.2-beta.1"):
        (work / "version").write_text(v + "\n")
        git(work, "add", "version")
        git(work, "commit", "-q", "--allow-empty", "-m", v)
    git(work, "tag", "0.4.0", "HEAD~3")
    git(work, "tag", "-a", "-m", "release", "0.4.1", "HEAD~2")
    git(work, "tag", "0.4.2-beta.1", "HEAD~1")
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
    # every parse case: version_key accepts exactly the versions
    for case in FIXTURE["parse"]:
        r = sh('version_key "$1"', home, case["tag"])
        check((r.returncode == 0) == (case["version"] is not None), f"version_key {case['tag']!r}: exit {r.returncode}")
    # compare: the keys order the versions as the fixture does
    for a, b, want in FIXTURE["compare"]:
        r = sh('a="$(version_key "$1")"; b="$(version_key "$2")"; if [[ "$a" > "$b" ]]; then echo 1; '
               'elif [[ "$a" < "$b" ]]; then echo -1; else echo 0; fi', home, a, b)
        check(r.stdout.strip() == str(want), f"compare {a} {b}: {r.stdout.strip()!r}, want {want}")
    # the version floor
    r = sh('echo "$LAST_RELEASE_WITHOUT_CHANNELS"', home)
    check(r.stdout.strip() == FIXTURE["lastReleaseWithoutChannels"], f"floor {r.stdout.strip()!r}")
    for case in FIXTURE["hasChannels"]:
        r = sh('has_channels "$1"', home, case["tag"])
        check((r.returncode == 0) == case["want"], f"has_channels {case['tag']}: exit {r.returncode}")


def test_options(home):
    r = sh('parse_args --channel nightly', home)
    check(r.returncode != 0 and "Unknown update channel: nightly" in r.stderr, f"bad channel accepted: {r.stderr}")
    r = sh('parse_args --branch dev --channel beta', home)
    check(r.returncode != 0 and "--branch follows a branch" in r.stderr, f"--branch with beta: {r.stderr}")
    r = sh('parse_args --ref 0.4.1', home)
    check(r.returncode != 0 and "--ref needs --channel" in r.stderr, f"--ref alone: {r.stderr}")
    for old in ("0.3.1", "v0.1.2", "0.3.1-beta.2", "nightly"):
        r = sh(f'parse_args --channel stable --ref {old}', home)
        check(r.returncode != 0 and "is not a release with update channels" in r.stderr, f"--ref {old}: {r.stderr}")
    r = sh('parse_args --update --channel stable --ref 0.4.1 --allow-downgrade; echo "$ALLOW_DOWNGRADE"', home)
    check(r.stdout.strip() == "1", f"--allow-downgrade: {r.stdout!r} {r.stderr}")
    r = sh('parse_args --update --channel beta --ref 0.4.2-beta.1; echo "$CHANNEL $REF $CHANNEL_SET"', home)
    check(r.stdout.strip() == "beta 0.4.2-beta.1 1", f"parsed: {r.stdout!r} {r.stderr}")
    r = sh('parse_args --branch dev; echo "$CHANNEL"', home)
    check(r.stdout.strip() == "git", f"--branch is the git channel: {r.stdout!r}")
    r = sh('usage', home)
    check("--channel NAME" in r.stdout and "--ref TAG" in r.stdout, "usage lacks --channel / --ref")
    check("follows main, as before" not in r.stdout, "usage still says a first install follows main")
    check("update channel git" in r.stdout and "newer than 0.3.1" in r.stdout, f"usage: {r.stdout}")


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
    r = sync(home, src, origin, "stable", "0.4.1")
    check(commit_of(src, "HEAD") == commit_of(src, "0.4.1"), f"--ref 0.4.1 not checked out: {r.stderr}")
    check("RELEASE_TAG=0.4.1" in r.stdout, f"RELEASE_TAG: {r.stdout}")

    # from 0.4.1 the beta channel moves forward on its own
    r = sync(home, src, origin, "beta")
    check(commit_of(src, "HEAD") == commit_of(src, "0.4.2-beta.1"), f"beta did not move forward: {r.stderr}")
    check("Sources at 0.4.2-beta.1 (beta channel)" in r.stderr, f"beta message: {r.stderr}")

    # a new stable release on origin: a beta user follows it
    other = root / "other"
    git(root, "clone", "-q", str(origin), str(other))
    (other / "version").write_text("0.4.2\n")
    git(other, "commit", "-q", "-am", "0.4.2")
    git(other, "tag", "0.4.2")
    git(other, "push", "-q", "origin", "main", "0.4.2")
    r = sync(home, src, origin, "beta")
    check(commit_of(src, "HEAD") == commit_of(src, "0.4.2"), f"beta stuck behind stable: {r.stderr}")
    check("RELEASE_TAG=0.4.2" in r.stdout, f"RELEASE_TAG after the stable release: {r.stdout}")

    # local changes are kept (no reset), on a tag channel too
    r = sync(home, src, origin, "stable", "0.4.1")
    check(commit_of(src, "HEAD") == commit_of(src, "0.4.1"), "--ref 0.4.1 again")
    (src / "version").write_text("mine\n")
    r = sync(home, src, origin, "beta")
    check(commit_of(src, "HEAD") == commit_of(src, "0.4.1"), "a dirty checkout was moved")
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
    check(commit_of(fresh, "HEAD") == commit_of(fresh, "0.4.2"), f"fresh stable clone not at 0.4.2: {r.stderr}")
    # and without a channel (first install, no setting): main, as before
    legacy = root / "legacy"
    r = sync(home, legacy, origin, "")
    check(git(legacy, "rev-parse", "--abbrev-ref", "HEAD") == "main", f"first install left main: {r.stderr}")

    # dry run: nothing moves, the step is described
    before = commit_of(src, "HEAD")
    r = sh(f'REPO_URL={origin}; SRC_DIR={src}; CHANNEL=stable; DRY_RUN=1; LOG_FILE={home}/cache/install.log\nsync_repo', home)
    check(commit_of(src, "HEAD") == before, "dry run moved the checkout")
    check("would run: git -C" in r.stderr and "checkout -q --detach" in r.stderr, f"dry run note: {r.stderr}")


def push_release(root, origin, tag, drop=(), commit=True):
    """From a second clone of origin: delete the tags in drop, commit on main
    (unless commit is False) and tag that commit (force-pushed: a re-created
    tag replaces the old one)."""
    other = root / f"other-{tag}"
    git(root, "clone", "-q", str(origin), str(other))
    for t in drop:
        git(other, "push", "-q", "origin", f":refs/tags/{t}")
    if commit:
        git(other, "commit", "-q", "--allow-empty", "-m", tag)
        git(other, "push", "-q", "origin", "main")
    git(other, "tag", "-f", tag)
    git(other, "push", "-q", "--force", "origin", tag)
    return commit_of(other, "HEAD")


def test_pre_channel_releases(home, root):
    """Only tags that predate update channels (today's 0.1.1 ... 0.3.1): a
    tag channel has no target; a fresh install builds main as before."""
    origin = make_origin(root)
    push_release(root, origin, "0.3.1", drop=("0.4.0", "0.4.1", "0.4.2-beta.1"))
    push_release(root, origin, "v0.1.2", commit=False)
    for ch in ("stable", "beta"):
        fresh = root / f"fresh-{ch}"
        r = sync(home, fresh, origin, ch)
        check(r.returncode == 0, f"{ch} fresh exit {r.returncode}: {r.stderr}")
        check(git(fresh, "rev-parse", "--abbrev-ref", "HEAD") == "main", f"{ch}: fresh clone left main: {r.stderr}")
        check(f"No {ch} release with update channels yet (releases up to 0.3.1 predate them); building main as it is"
              in r.stderr, f"{ch}: no explanation: {r.stderr}")
        check("RELEASE_TAG=" in r.stdout.splitlines(), f"{ch}: RELEASE_TAG {r.stdout}")
        # an existing install is not moved either
        tip = commit_of(fresh, "HEAD")
        r = sync(home, fresh, origin, ch)
        check(r.returncode == 0 and commit_of(fresh, "HEAD") == tip, f"{ch}: existing install moved: {r.stderr}")
    # --allow-downgrade cannot reach them either
    r = sync(home, root / "fresh-stable", origin, "stable", extra="ALLOW_DOWNGRADE=1")
    check(git(root / "fresh-stable", "rev-parse", "--abbrev-ref", "HEAD") == "main", f"--allow-downgrade moved: {r.stderr}")


def test_remote_tags_only(home, root):
    """Without --ref the target comes from origin's tags, not tags made here."""
    origin = make_origin(root)
    src = root / "src"
    git(root, "clone", "-q", str(origin), str(src))
    git(src, "checkout", "-q", "--detach", "0.4.0")
    git(src, "tag", "9.9.9", "main")
    r = sync(home, src, origin, "stable")
    check(commit_of(src, "HEAD") == commit_of(src, "0.4.1"), f"local tag picked over origin's: {r.stderr}")
    check("RELEASE_TAG=0.4.1" in r.stdout, f"RELEASE_TAG: {r.stdout}")


def test_local_commits(home, root):
    """Commits made here are not left out by moving to a release without them."""
    origin = make_origin(root)
    src = root / "src"
    git(root, "clone", "-q", str(origin), str(src))
    (src / "version").write_text("tweak\n")
    git(src, "commit", "-q", "-am", "my tweak")
    mine = commit_of(src, "HEAD")
    push_release(root, origin, "0.5.0")
    for ch in ("stable", "beta"):
        r = sync(home, src, origin, ch, "0.5.0")
        check(r.returncode == 0, f"{ch} exit {r.returncode}: {r.stderr}")
        check(commit_of(src, "HEAD") == mine, f"{ch} --ref left the local commit out: {r.stderr}")
        check("1 commit(s) on no branch of origin that 0.5.0 does not contain" in r.stderr, f"{ch} warning: {r.stderr}")
        check("--allow-downgrade" in r.stderr, f"{ch}: no override named: {r.stderr}")
    r = sync(home, src, origin, "stable", "0.5.0", extra="ALLOW_DOWNGRADE=1")
    check(commit_of(src, "HEAD") == commit_of(src, "0.5.0"), f"--allow-downgrade did not move: {r.stderr}")
    check(git(src, "rev-parse", "main") == mine, "the local commit is gone from main")


def test_moved_tag(home, root):
    """A release tag re-created on origin: the fetch does not fail and the
    checkout lands on origin's commit."""
    origin = make_origin(root)
    src = root / "src"
    git(root, "clone", "-q", str(origin), str(src))
    git(src, "checkout", "-q", "--detach", "0.4.1")
    moved = push_release(root, origin, "0.4.2-beta.1")
    r = sync(home, src, origin, "beta")
    check(r.returncode == 0, f"fetch failed on a moved tag: {r.stderr}")
    check(commit_of(src, "HEAD") == moved, f"not at origin's 0.4.2-beta.1: {r.stderr}")
    r = sync(home, src, origin, "beta", "0.4.2-beta.1")
    check(r.returncode == 0 and commit_of(src, "HEAD") == moved, f"second run: {r.stderr}")


def test_download_release_url(home, root):
    script = ('curl() { printf "%s\\n" "$*" >>"$CALLS"; return 22; }\n'
              f'REPO_URL=https://example.invalid/o/r.git; SRC_DIR={root}\n'
              'RELEASE_TAG=0.4.2-beta.1; download_release || true\nRELEASE_TAG=; download_release || true\n')
    calls = root / "curl-calls"
    lib_env = f"CALLS={calls}\n"
    sh(lib_env + script, home)
    lines = calls.read_text().splitlines() if calls.exists() else []
    check(any("https://example.invalid/o/r/releases/download/0.4.2-beta.1/SHA256SUMS" in x for x in lines),
          f"tag channel does not download its release: {lines}")
    check(any("https://example.invalid/o/r/releases/latest/download/SHA256SUMS" in x for x in lines),
          f"no tag: not the latest release: {lines}")

    # a tag without release assets (v-prefixed tags, a beta without
    # assets): a clear failure, never another release's binaries
    for tag in ("v0.4.2", "0.4.3-beta.1"):
        calls.unlink(missing_ok=True)
        script = ('curl() { printf "%s\\n" "$*" >>"$CALLS"; [[ "$*" != *"/releases/download/"* ]]; }\n'
                  f'REPO_URL=https://example.invalid/o/r.git; SRC_DIR={root}\n'
                  f'RELEASE_TAG={tag}; download_release && echo exit=0 || echo "exit=$?"\n')
        r = sh(lib_env + script, home)
        lines = calls.read_text().splitlines()
        check(len(lines) == 1 and f"releases/download/{tag}/SHA256SUMS" in lines[0], f"{tag}: only its own release: {lines}")
        check(not any("/latest/" in x for x in lines), f"{tag}: fell back to the latest release: {lines}")
        check("exit=1" in r.stdout, f"{tag}: did not fail: {r.stdout}")
        check(f"release {tag} has no prebuilt binaries; build it from source" in r.stdout, f"{tag}: not said: {r.stdout}")


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
    tests = [test_pick_tag_fixture, test_options, test_resolve_channel, test_sync_repo, test_pre_channel_releases,
             test_remote_tags_only, test_local_commits, test_moved_tag,
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
