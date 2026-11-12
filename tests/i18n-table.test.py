"""I18n keeps one lookup table: the selected language over the English fallback.

Loads the real modules/services/I18n.qml with FileView/Config stubbed and
checks that t(), tn() and has() answer as the former two-dictionary lookup
did (`strings[key] ?? fallback[key] ?? humanize(key)`), on fixtures and on
every key of the real translation files, across runtime language switches
and with a missing or broken language file.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

REPO = Path(__file__).resolve().parents[1]

h = Harness("i18n-table")
h.module("Quickshell", {
    "Singleton": "Item {}",
    "Quickshell": "pragma Singleton\nQtObject { function env(name) { return \"\"; } }",
})
h.module("Quickshell.Io", {
    # File contents by file name; a missing entry reads as "" (no file).
    "Files": "pragma Singleton\nQtObject { property var data: ({}) }",
    "FileView": """QtObject {
        property string path
        property bool blockLoading
        function text() {
            const name = path.substring(path.lastIndexOf("/") + 1);
            return path !== "" && Files.data[name] !== undefined ? Files.data[name] : "";
        }
    }""",
})
h.singleton("qs.config", "Config", "QtObject { property QtObject system: QtObject { property string language: \"en\" } }")
h.copy("modules/services/I18n.qml", "qs/modules/services")
h.module("qs.modules.services", {})

root = h.load("""import QtQuick
import Quickshell.Io
import qs.config
import qs.modules.services
Item {
    function setFiles(json) { Files.data = JSON.parse(json); }
    function setLanguage(lang) { Config.system.language = lang; }
    function reload() { I18n.loadAll(); }
    function translate(keys) { return JSON.stringify(keys.map(k => I18n.t(k))); }
    function known(keys) { return JSON.stringify(keys.map(k => I18n.has(k))); }
}""", auto_stub=False)

ok_all = True


def check(name, ok, detail=""):
    global ok_all
    ok_all &= bool(ok)
    print(("PASS " if ok else "FAIL ") + name + (" " + detail if detail else ""))


def ev(expr):
    return h.eval(root, expr)


def set_files(files):
    ev(f"setFiles({json.dumps(json.dumps(files))})")


def translate(keys):
    return json.loads(ev(f"translate({json.dumps(keys)})"))


def known(keys):
    return json.loads(ev(f"known({json.dumps(keys)})"))


def humanize(key):
    seg = key[key.rfind(".") + 1:].replace("_", " ")
    return seg[:1].upper() + seg[1:]


def expected(en, lang, key):
    """The former lookup: strings[key] ?? fallback[key] ?? humanize(key)."""
    for table in (lang, en):
        if table.get(key) is not None:
            return table[key]
    return humanize(key)


LANGS = json.dumps({"en": "English", "es": "Español", "xx": "Missing", "yy": "Broken"})
EN = {"a.hello": "Hello", "a.both": "Both EN", "a.nulled": "Fallback text", "a.empty": "EN empty",
      "a.args": "%1 of %2", "a.files.one": "%1 file", "a.files.other": "%1 files"}
ES = {"a.both": "Ambos", "a.nulled": None, "a.empty": "", "a.only_es": "Solo ES",
      "a.null_only": None, "a.args": "%2 de %1", "a.files.one": "%1 archivo"}
set_files({"languages.json": LANGS, "en.json": json.dumps(EN), "es.json": json.dumps(ES),
           "yy.json": "{ not json"})
KEYS = sorted(set(EN) | set(ES) | {"a.missing_key"})

# English: the fallback file is the table.
ev('setLanguage("en")')
check("english text", translate(["a.hello"]) == ["Hello"])
check("english matches the two-table lookup", translate(KEYS) == [expected(EN, {}, k) for k in KEYS])
check("missing key is humanized", translate(["a.missing_key"]) == ["Missing key"])
check("has() in english", known(KEYS) == [k in EN for k in KEYS])

# Runtime switch to Spanish.
rev = ev("I18n.revision")
ev('setLanguage("es")')
check("switch bumps the revision", ev("I18n.revision") > rev)
check("resolved language follows the config", ev("I18n.resolvedLanguage") == "es")
check("spanish matches the two-table lookup", translate(KEYS) == [expected(EN, ES, k) for k in KEYS],
      str(translate(KEYS)))
check("null entry keeps the english text", translate(["a.nulled"]) == ["Fallback text"])
check("empty string is a translation", translate(["a.empty"]) == [""])
check("key only in the language file", translate(["a.only_es"]) == ["Solo ES"])
check("arguments substitute", ev('I18n.t("a.args", 3, 7)') == "7 de 3")
# has(): the former `strings[key] !== undefined || fallback[key] !== undefined`.
check("has() in spanish", known(KEYS) == [k in EN or k in ES for k in KEYS])
check("tn() falls back per plural form", ev('I18n.tn("a.files", 1)') == "1 archivo"
      and ev('I18n.tn("a.files", 4)') == "4 files")
check("one table, no second dictionary", ev("I18n.strings === undefined && I18n.fallback === undefined"))

# Back to English: nothing of the merged Spanish table remains.
ev('setLanguage("en")')
check("back to english", translate(KEYS) == [expected(EN, {}, k) for k in KEYS], str(translate(KEYS)))
check("spanish-only key gone after switching back", known(["a.only_es"]) == [False])

# A listed language whose file is missing, or broken: English everywhere.
for lang in ("xx", "yy"):
    ev(f'setLanguage("{lang}")')
    check(f"{lang}: falls back to english", translate(KEYS) == [expected(EN, {}, k) for k in KEYS])
    check(f"{lang}: has() as english", known(KEYS) == [k in EN for k in KEYS])
    check(f"{lang}: ready", ev("I18n.ready") is True)

# A language that is not listed resolves to English.
ev('setLanguage("zz")')
check("unlisted language resolves to en", ev("I18n.resolvedLanguage") == "en")

# No English file: nothing is ready, keys are humanized, the language still applies.
set_files({"languages.json": LANGS, "es.json": json.dumps(ES)})
ev('setLanguage("es")')
ev("reload()")
check("no fallback: not ready", ev("I18n.ready") is False)
check("no fallback: language text still used", translate(["a.both", "a.hello"]) == ["Ambos", "Hello"])

# The real translation files: every key answers as before.
real = {p.stem: p.read_text() for p in (REPO / "translations").glob("*.json")}
set_files({f"{name}.json": text for name, text in real.items()})
en = json.loads(real["en"])
for lang in sorted(json.loads(real["languages"])):
    if lang == "en" or lang not in real:
        continue
    ev(f'setLanguage("{lang}")')
    ev("reload()")
    table = json.loads(real[lang])
    keys = sorted(set(en) | set(table))
    got = translate(keys)
    want = [expected(en, table, k) for k in keys]
    bad = [k for k, g, w in zip(keys, got, want, strict=True) if g != w]
    check(f"{lang}.json: t() over {len(keys)} keys", not bad, str(bad[:5]))
    check(f"{lang}.json: has()", known(keys) == [True] * len(keys))

sys.exit(0 if ok_all else 1)
