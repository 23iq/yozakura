"""The translations audit understands plural families (<key>.one/.few/.other)."""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools" / "audit"))
from checks.translations import TN_CALL, plural_base, plural_issues  # noqa: E402

failures = []

for key, base in [("a.b.one", "a.b"), ("a.other", "a"), ("x.few", "x"), ("x.many", "x"),
                  ("x.zero", "x"), ("x.two", "x"), ("a.b.title", None), ("one", None), ("a.oneself", None)]:
    if plural_base(key) != base:
        failures.append(f"plural_base({key!r}) = {plural_base(key)!r}, want {base!r}")

# Extra categories in one language are fine; a missing .other is not.
ok = {"en": {"n.one": "1", "n.other": "%1"}, "ru": {"n.one": "1", "n.few": "f", "n.many": "m", "n.other": "o"},
      "ja": {"n.other": "%1"}}
if plural_issues(ok):
    failures.append(f"complete family reported: {plural_issues(ok)}")
bad = {"en": {"n.one": "1", "n.other": "%1"}, "ru": {"n.one": "1", "n.few": "f"}}
got = plural_issues(bad)
if [i.key for i in got] != ["ru:n.other"] or got[0].severity != "error":
    failures.append(f"missing .other not an error: {got}")
if plural_issues({"en": {"a.title": "t"}, "ru": {"a.title": "т"}}):
    failures.append("plain keys are not plural families")

for src, want in [('I18n.tn("prefs.n_on", 3)', "prefs.n_on"), ("I18n.tn( 'x.y', n)", "x.y"), ("I18n.t('x.y')", None)]:
    m = TN_CALL.search(src)
    if (m and src[m.end():].split(m.group(1))[0]) != want:
        failures.append(f"TN_CALL on {src!r}")

if failures:
    print("FAIL translations-audit:\n  " + "\n  ".join(failures))
    sys.exit(1)
print("ok translations-audit")
