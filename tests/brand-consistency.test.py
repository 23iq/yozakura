"""The app identity is declared once per language; all copies must agree.

Go (backend/pkg/brand), JS (modules/globals/BrandActions.js, read by the QML
Brand singleton), shell (scripts/lib/brand.sh) and Python
(scripts/lib/brand.py) each carry the ids. This test fails as soon as one of
them drifts, and checks the env-var fallback of the script helpers.
"""
import os
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "scripts" / "lib"))
import brand  # noqa: E402

failures = []


def check(name, got, want):
    if got != want:
        failures.append(f"{name}: got {got!r}, want {want!r}")


go = (REPO / "backend/pkg/brand/brand.go").read_text()
js = (REPO / "modules/globals/BrandActions.js").read_text()
sh = (REPO / "scripts/lib/brand.sh").read_text()


def grab(src, pattern, label):
    m = re.search(pattern, src, re.M)
    if not m:
        failures.append(f"{label}: pattern {pattern!r} not found")
        return None
    return m.group(1)


for key, go_name, js_name, sh_name, py_value in (
    ("app id", "AppID", "appId", "BRAND_APP_ID", brand.APP_ID),
    ("display name", "DisplayName", "displayName", "BRAND_DISPLAY_NAME", brand.DISPLAY_NAME),
    ("legacy id", "LegacyAppID", "legacyAppId", "BRAND_LEGACY_APP_ID", brand.LEGACY_APP_ID),
    ("daemon", "Daemon", "daemon", "BRAND_DAEMON", brand.DAEMON),
):
    g = grab(go, rf'^\s*{go_name}\s*=\s*"([^"]+)"', f"go {key}")
    j = grab(js, rf'^var {js_name} = "([^"]+)";', f"js {key}")
    s = grab(sh, rf'^{sh_name}="([^"]+)"', f"sh {key}")
    for lang, value in (("js", j), ("sh", s), ("py", py_value)):
        check(f"{lang} {key} vs go", value, g)

for py_value, go_name, sh_name in ((brand.ENV_PREFIX, "EnvPrefix", "BRAND_ENV_PREFIX"),
                                   (brand.LEGACY_ENV_PREFIX, "LegacyEnvPrefix", "BRAND_LEGACY_ENV_PREFIX")):
    g = grab(go, rf'^\s*{go_name}\s*=\s*"([^"]+)"', f"go {go_name}")
    check(f"py {go_name} vs go", py_value, g)
    check(f"sh {go_name} vs go", grab(sh, rf'^{sh_name}="([^"]+)"', f"sh {go_name}"), g)

# Env fallback: legacy prefix is read when the current one is unset.
env = {k: v for k, v in os.environ.items() if not k.endswith("_BRANDTEST")}
env[brand.LEGACY_ENV_PREFIX + "BRANDTEST"] = "legacy"
out = subprocess.run(["bash", "-c", '. scripts/lib/brand.sh; brand_env BRANDTEST fallback'],
                     cwd=REPO, env=env, capture_output=True, text=True).stdout
check("sh legacy fallback", out, "legacy")
env[brand.ENV_PREFIX + "BRANDTEST"] = "current"
out = subprocess.run(["bash", "-c", '. scripts/lib/brand.sh; brand_env BRANDTEST fallback'],
                     cwd=REPO, env=env, capture_output=True, text=True).stdout
check("sh current prefix wins", out, "current")
env.pop(brand.ENV_PREFIX + "BRANDTEST")
env.pop(brand.LEGACY_ENV_PREFIX + "BRANDTEST", None)
out = subprocess.run(["bash", "-c", '. scripts/lib/brand.sh; brand_env BRANDTEST fallback'],
                     cwd=REPO, env=env, capture_output=True, text=True).stdout
check("sh default", out, "fallback")

os.environ.pop(brand.ENV_PREFIX + "BRANDTEST", None)
os.environ[brand.LEGACY_ENV_PREFIX + "BRANDTEST"] = "legacy"
check("py legacy fallback", brand.brand_env("BRANDTEST", "x"), "legacy")
os.environ[brand.ENV_PREFIX + "BRANDTEST"] = "current"
check("py current prefix wins", brand.brand_env("BRANDTEST", "x"), "current")

if failures:
    print("\n".join(failures))
    sys.exit(1)
print("brand identity consistent across go/js/sh/py")
