"""The shell-injection audit flags data spliced into QML source or shell code.

Fixtures cover the patterns from the security review (createQmlObject with
an escaped file name, `sh -c` strings built with + or ${}) and the safe
forms that must stay quiet (positional "$1" args, static sources, comments).
"""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools" / "audit"))
from checks.shell_injection import run, scan_text  # noqa: E402

failures = []

BAD = {
    "createQmlObject concat": """
        var p = Qt.createQmlObject('import Quickshell.Io; Process { command: ["gio", "trash", "' + path + '"] }', root);
    """,
    "createQmlObject template": """
        let proc = Qt.createQmlObject(`
            import Quickshell.Io
            Process { command: ["sh", "-c", "${escapedCmd}"] }
        `, root, "dyn");
    """,
    "bash -c concat": """
        proc.command = ["bash", "-c", "gio trash '" + escapedPath + "'"];
    """,
    "sh -c template": """
        command: ["sh", "-c", `wal -i '${path}' -n`]
    """,
    "sh -lc multi-line concat": """
        command: ["/bin/sh", "-lc",
            "cat " +
            file]
    """,
    "sh -c join": """
        p.command = ["sh", "-c", parts.join(" ")];
    """,
    "execDetached sh -c": """
        Quickshell.execDetached(["sh", "-c", "xdg-open " + url]);
    """,
    "terminal -e bash -c": """
        Quickshell.execDetached([term, "-e", "bash", "-c", "cd " + dir + "; exec bash"]);
    """,
    "script variable built with +": """
        const cmd = "cat '" + file + "'";
        proc.command = ["sh", "-c", cmd];
    """,
    "script variable built with +=": """
        let cmd = "cat ";
        cmd += file;
        proc.command = ["bash", "-c", cmd]
    """,
    "QML-style statement without semicolons": """
        const cmd = `wal -i "${path}"`
        writerProcess.command = ["sh", "-c", cmd]
    """,
    "sh -c inside a string": """
        var line = "kitty -e sh -c '" + cmd + "'";
    """,
}

GOOD = {
    "positional args": """
        command: ["sh", "-c", 'printf "%s" "$1" > "$2"', "writer", content, path]
    """,
    "static createQmlObject": """
        var p = Qt.createQmlObject('import Quickshell.Io; Process { }', root);
        p.command = ["gio", "trash", "--", path];
    """,
    "constant script": """
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null"]
    """,
    "script in a variable": """
        writer.command = ["sh", "-c", root.script, "name", a, b];
    """,
    "constant script variable": """
        const cmd = 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"';
        writerProcess.command = ["sh", "-c", cmd, Brand.appId + "-x", path, conf];
    """,
    "shell variables in a plain string": """
        argument: "sh -c 'echo up > \\"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pipe\\"'",
    """,
    "-c of another program": """
        var c = ["matugen", "image", src, "-c", root.dir + "/config.toml"];
    """,
    "commented out": """
        // proc.command = ["bash", "-c", "cat " + file];
        /* Qt.createQmlObject('x' + y, root) */
    """,
    "regex with quotes": """
        var s = x.replace(/'/g, "'\\\\''"); command: ["sh", "-c", "true"]
    """,
}

for name, src in BAD.items():
    if not scan_text(src):
        failures.append(f"not flagged: {name}")
for name, src in GOOD.items():
    got = scan_text(src)
    if got:
        failures.append(f"false positive: {name}: {got}")

# Allowlist entries need a reason; unknown/stale entries are reported.
issues = run({"shellInjection": {"allow": {"modules/x.qml::foo": ""}}})
if not any("needs" in i.message for i in issues if i.severity == "error"):
    failures.append("allowlist entry without a reason is not an error")
issues = run({"shellInjection": {"allow": {"modules/none.qml::nothing": "gone"}}})
if not any("stale" in i.message for i in issues):
    failures.append("stale allowlist entry not reported")

if failures:
    print("FAIL shell-injection-audit:\n  " + "\n  ".join(failures))
    sys.exit(1)
print(f"ok shell-injection-audit: {len(BAD)} bad, {len(GOOD)} good fixtures")
