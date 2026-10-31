"""The layer audit finds upward imports and cycles, and ratchets against a baseline."""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools" / "audit"))
from checks import layers  # noqa: E402
from lib.model import repo_files  # noqa: E402

failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)


L = layers.DEFAULT_LAYERS

check(layers.module_of(".modules.bar.panels") == "bar", "modules.<X>.sub -> X")
check(layers.module_of(".config.adapters") == "config", "qs.config.* -> config")
check(layers.module_of(".other") is None, "unknown roots ignored")
check(layers.file_node("modules/bar/BarContent.qml") == "bar", "file node of a module file")
check(layers.file_node("config/Config.qml") == "config", "file node of config")
check(layers.file_node("shell.qml") == layers.ROOT_NODE, "root entry file")

src = {
    "modules/theme/Colors.qml": "import qs.modules.services\nItem {}",
    "modules/services/Net.qml": "import qs.config\nimport qs.modules.theme\n",
    "modules/bar/A.qml": "import qs.modules.services\nimport qs.modules.notch\nimport qs.modules.shell",
    "modules/notch/B.qml": "// import qs.modules.shell\nimport qs.modules.bar\n",
    "modules/shell/S.qml": "import qs.modules.bar\n",
    "modules/bar/helper.js": ".import qs.modules.shell as S\n",
    "shell.qml": "import qs.modules.shell\n",
}
r = layers.analyze(src, L)
check(r["upward"].get("theme -> services") == 1, f"foundation importing services is upward: {r['upward']}")
check("services -> theme" not in r["upward"], "downward import is fine")
check(r["upward"].get("bar -> shell") == 2, f"counts importing files (qml + js): {r['upward']}")
check("notch -> shell" not in r["upward"], "commented import ignored")
check("shell -> bar" not in r["upward"], "shell may import features")
check(["bar", "notch"] in r["cycles"], f"bar <-> notch is a cycle: {r['cycles']}")
check(["bar", "shell"] in r["cycles"], "bar <-> shell is a cycle")

base = {"upward": {"theme -> services": 1, "bar -> shell": 2}, "cycles": [["bar", "notch"], ["bar", "shell"], ["services", "theme"]]}
new, better = layers.compare(r, base)
check(new == [], f"matching baseline has no new violations: {new}")
check(better == [], f"and nothing improved: {better}")

worse = dict(r, upward={**r["upward"], "bar -> shell": 3, "dock -> shell": 1}, cycles=r["cycles"] + [["dock", "notch"]])
new, _ = layers.compare(worse, base)
check(any("more upward imports bar -> shell" in m for m in new), "growth of a baselined pair fails")
check(any("new upward import dock -> shell" in m for m in new), "new pair fails")
check(any("dock <-> notch" in m for m in new), "new cycle fails")

fixed = dict(r, upward={"theme -> services": 1}, cycles=[["bar", "notch"], ["services", "theme"], ["bar", "shell"]])
new, better = layers.compare(fixed, base)
check(new == [] and len(better) == 1, f"fixing violations only suggests a refresh: {new} {better}")

check(not any(f.startswith(".claude/") for f in repo_files(".qml", ".js")), "agent worktrees are never scanned")

if failures:
    print("\n".join("FAIL: " + f for f in failures))
    sys.exit(1)
print("layers audit: ok")
