"""Shared harness for offscreen QML tests (PySide6, no compositor needed).

Typical use::

    import sys, pathlib; sys.path.insert(0, str(pathlib.Path(__file__).parent))
    from lib.qmlharness import Harness

    h = Harness("palette")
    h.singleton("qs.config", "Config", "QtObject { property int animDuration: 300 }")
    h.module("Quickshell.Io", {"Process": "QtObject { property var command; property bool running }"})
    colors = h.copy("modules/theme/Colors.qml", strip_singleton=True)
    obj = h.load(colors)          # unknown types are auto-stubbed, see below
    h.eval(obj, "primary")

What it does for you:
  * `module()` / `singleton()` write stub modules (with qmldir) into a temp
    import root; bodies may omit `import QtQuick` and `pragma Singleton`.
  * `copy()` copies a repo QML file plus everything it references relatively:
    `import "X.js"`, `.import` inside JS, `import "./Y.qml"`, sibling types in
    the same directory, and string literals that name existing files
    (shaders `*.qsb`, `Qt.resolvedUrl("...")`, sounds, ...).
  * `load()` creates the component; on "X is not a type" it writes an empty
    stub type next to the file that needs it - unless X exists as a .qml file
    in the repo: then it fails loudly (copy the real file, or stub it
    explicitly with `stub()` / `module()`), so a real resolution failure is
    never papered over, on "Cannot assign to
    non-existent property" against such a stub it adds the property (or a
    signal for `onFoo` handlers), on `module "M" is not installed` it creates
    an empty module, then retries. Every auto-stub is printed so tests stay
    explicit about what is faked; pass `auto_stub=False` to forbid them.
    Stubbing a missing module recreates `h.engine` (Qt caches failed
    imports), so read `h.engine` after `load()`.

  * Runtime type errors ("X is not a type", "Type X unavailable", e.g. from
    a Loader or a deferred `layer.effect`) are recorded in
    `h.type_errors`; the process exits non-zero at the end if any were seen
    (`h.allow_type_errors = True` to opt out).

Set QML_HARNESS_KEEP=1 to keep the temp tree for debugging.
"""
from __future__ import annotations

import atexit
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import headless  # noqa: E402,F401  (offscreen, no WAYLAND_DISPLAY/DISPLAY: never a live window)

from PySide6.QtCore import QObject, QUrl, qInstallMessageHandler  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtQml import QQmlComponent, QQmlEngine, QQmlExpression  # noqa: E402

# Load libQt6Multimedia on the main thread now. Otherwise the QML type loader
# thread dlopens it on the first `import QtMultimedia`, and its static init
# logs (e.g. "Couldn't load pipewire-0.3 library" on hosts without PipeWire).
# A Python message handler then needs the GIL, which the main thread holds
# inside the blocking setSource()/evaluate() that started the load: deadlock.
try:
    import PySide6.QtMultimedia  # noqa: E402,F401
except ImportError:
    pass

REPO = Path(__file__).resolve().parents[2]

_REL_IMPORT = re.compile(r'^\s*\.?import\s+"([^"]+)"', re.M)
_STRING = re.compile(r'"([^"\n]+)"|\'([^\'\n]+)\'')
_TYPE_USE = re.compile(r"\b([A-Z]\w*)\s*\{")
_NOT_A_TYPE = re.compile(r"(file://\S+?\.qml):(\d+):\d+: ([\w.]+) is not a type")
_NO_PROP = re.compile(r'(file://\S+?\.qml):(\d+):(\d+): Cannot assign to non-existent property "(\w+)"')
# "not installed", or installed system-wide but its C++ plugin cannot load under PySide6.
_TYPE_ERROR = re.compile(r"\b[\w.]+ is not a type\b|\bType \w+ unavailable\b")
_NO_MODULE = re.compile(r'module "([\w.]+)" (?:is not installed|plugin "[^"]+" not found)')


def _qml_body(body: str, singleton: bool = False) -> str:
    body = body.strip()
    has_pragma = body.startswith("pragma Singleton")
    if has_pragma:
        body = body.split("\n", 1)[1].lstrip()
    if not re.search(r"^\s*import\s+Qt(Quick|Qml)\b", body, re.M):
        body = "import QtQuick\n" + body
    return ("pragma Singleton\n" if singleton or has_pragma else "") + body + "\n"


HARNESS_HOME = "/tmp/qmlharness-home"


def brand_qml(home: str = HARNESS_HOME) -> str:
    """The real modules/globals/Brand.qml without its Quickshell dependency:
    a QtObject singleton whose env lookups resolve against `home` (XDG_*
    unset, XDG_RUNTIME_DIR = /tmp)."""
    text = (REPO / "modules/globals/Brand.qml").read_text()
    text = re.sub(r"^import Quickshell\s*$", "", text, flags=re.M)
    text = text.replace("Singleton {", "QtObject {", 1)
    text = re.sub(r'Quickshell\.env\("HOME"\)', f'"{home}"', text)
    text = re.sub(r'Quickshell\.env\("XDG_RUNTIME_DIR"\)', '"/tmp"', text)
    text = re.sub(r'Quickshell\.env\([^()]*\)', '""', text)
    return text


class Harness:
    def __init__(self, name: str = "qml", *, keep: bool | None = None):
        self.app = QGuiApplication.instance() or QGuiApplication([])
        self.root = Path(tempfile.mkdtemp(prefix=f"qmlharness-{name}-")).resolve()
        self.engine = QQmlEngine()
        self.engine.addImportPath(str(self.root))
        self.auto_stubs: list[str] = []
        self._stubbed: set[Path] = set()
        self._copied: set[Path] = set()
        self._n = 0
        self._alive: list[tuple[QQmlComponent | None, QObject]] = []
        self.type_errors: list[str] = []
        self.allow_type_errors = False
        self._prev_handler = qInstallMessageHandler(self._on_message)
        atexit.register(self._check_type_errors)
        keep = os.environ.get("QML_HARNESS_KEEP") == "1" if keep is None else keep
        self._keep = keep
        if not keep:
            atexit.register(shutil.rmtree, self.root, True)

    def exit(self, code: int) -> None:
        """Leave now: type check + temp cleanup, then os._exit(code).

        For tests that ran media/GL: skips the interpreter's destructor pass,
        where tearing down Qt Multimedia threads can deadlock.
        """
        self._check_type_errors()
        if not self._keep:
            shutil.rmtree(self.root, True)
        sys.stdout.flush()
        sys.stderr.flush()
        os._exit(code)

    def _on_message(self, mode, ctx, msg: str) -> None:
        if _TYPE_ERROR.search(msg):
            self.type_errors.append(msg)
        if self._prev_handler:
            self._prev_handler(mode, ctx, msg)
        else:
            print(msg, file=sys.stderr)

    def _check_type_errors(self) -> None:
        if self.type_errors and not self.allow_type_errors:
            print("qmlharness: QML type resolution failed at runtime:\n  " + "\n  ".join(self.type_errors),
                  file=sys.stderr)
            sys.stderr.flush()
            os._exit(1)

    def _new_engine(self) -> None:
        self._alive.append((None, self.engine))  # keep objects of the old engine valid
        self.engine = QQmlEngine()
        self.engine.addImportPath(str(self.root))

    # ------------------------------------------------------------- stubs
    def module(self, name: str, files: dict[str, str]) -> Path:
        """Create or extend stub module `name` with {TypeName: qml body}.

        `qs.modules.globals` always gets the real Brand singleton (app ids
        and dirs, see brand_qml()) unless the test passes its own Brand.
        """
        d = self.root / name.replace(".", "/")
        d.mkdir(parents=True, exist_ok=True)
        if name == "qs.modules.globals":
            shutil.copy(REPO / "modules/globals/BrandActions.js", d / "BrandActions.js")
            if "Brand" not in files and not (d / "Brand.qml").exists():
                files = {**files, "Brand": brand_qml()}
        for type_name, body in files.items():
            singleton = body.lstrip().startswith("pragma Singleton")
            (d / f"{type_name}.qml").write_text(_qml_body(body, singleton))
        self._write_qmldir(d, name)
        return d

    def singleton(self, module: str, name: str, body: str) -> Path:
        return self.module(module, {name: "pragma Singleton\n" + body})

    def stub(self, type_name: str, body: str = "Item {}", dest: str = "app") -> Path:
        """Write a plain (non-module) stub type next to copied files in <root>/<dest>."""
        d = self.root / dest
        d.mkdir(parents=True, exist_ok=True)
        path = d / f"{type_name}.qml"
        path.write_text(_qml_body(body))
        return path

    def _write_qmldir(self, d: Path, name: str) -> None:
        lines = [f"module {name}"]
        for f in sorted(d.glob("*.qml")):
            single = f.read_text().lstrip().startswith("pragma Singleton")
            lines.append(f"{'singleton ' if single else ''}{f.stem} 1.0 {f.name}")
        (d / "qmldir").write_text("\n".join(lines) + "\n")

    # -------------------------------------------------------------- copy
    def copy(self, rel: str | Path, dest: str = "app", *, strip_singleton: bool = False,
             siblings: bool = True, replace: dict[str, str] | None = None) -> Path:
        """Copy a repo file and its relative dependencies into <root>/<dest>."""
        src = (REPO / rel).resolve()
        target_dir = self.root / dest
        target_dir.mkdir(parents=True, exist_ok=True)
        out = target_dir / src.name
        text = src.read_text()
        if strip_singleton:
            text = re.sub(r"^\s*pragma Singleton\s*\n", "", text, count=1)
        for old, new in (replace or {}).items():
            text = text.replace(old, new)
        out.write_text(text)
        self._copied.add(src)
        self._copy_deps(src, text, target_dir, siblings)
        return out

    def _copy_deps(self, src: Path, text: str, target_dir: Path, siblings: bool) -> None:
        here = src.parent
        refs = set(_REL_IMPORT.findall(text))
        for m in _STRING.finditer(text):
            refs.add(m.group(1) or m.group(2))
        for ref in refs:
            if ref.startswith(("qrc:", "file:", "image:", "http")) or ref.startswith("/"):
                continue
            p = (here / ref).resolve()
            # Arbitrary string literals are probed as paths; a long prose
            # string raises ENAMETOOLONG on Python < 3.14 instead of False.
            try:
                is_file = p.is_file()
            except OSError:
                continue
            if not is_file or p in self._copied or REPO not in p.parents:
                continue
            dst = (target_dir / os.path.relpath(p, here)).resolve()
            if self.root not in dst.parents:
                continue
            self._copied.add(p)
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(p, dst)
            if p.suffix in (".qml", ".js"):
                self._copy_deps(p, p.read_text(), dst.parent, siblings)
        if siblings and src.suffix == ".qml":
            for type_name in set(_TYPE_USE.findall(text)):
                sib = here / f"{type_name}.qml"
                if sib.is_file() and sib.resolve() not in self._copied:
                    self.copy(sib.relative_to(REPO), str(target_dir.relative_to(self.root)), siblings=True)

    # -------------------------------------------------------------- load
    def write(self, qml: str, dest: str = "app", name: str | None = None) -> Path:
        self._n += 1
        d = self.root / dest
        d.mkdir(parents=True, exist_ok=True)
        path = d / (name or f"Harness{self._n}.qml")
        path.write_text(_qml_body(qml))
        return path

    def load(self, target: str | Path, *, auto_stub: bool = True, max_rounds: int = 25) -> QObject:
        """Create the component at `target` (a path, or inline QML source)."""
        path = Path(target) if isinstance(target, Path) or str(target).endswith(".qml") else self.write(target)
        # The type loader caches directory listings; files written since the
        # last load would otherwise fail with "File name case mismatch".
        self.engine.clearComponentCache()
        for _ in range(max_rounds):
            comp = QQmlComponent(self.engine, QUrl.fromLocalFile(str(path)))
            obj = comp.create()
            if obj is not None:
                self._alive.append((comp, obj))  # created objects die with their component
                return obj
            errors = "\n".join(e.toString() for e in comp.errors())
            if not auto_stub or not self._auto_stub(errors):
                raise AssertionError(f"{path.name} failed to load:\n{errors}")
            if _NO_MODULE.search(errors):
                self._new_engine()  # the import database caches "not installed"
            else:
                self.engine.clearComponentCache()
        raise AssertionError(f"{path.name}: gave up after {max_rounds} auto-stub rounds")

    def _auto_stub(self, errors: str) -> bool:
        changed = False
        for url, _line, type_name in _NOT_A_TYPE.findall(errors):
            if "." in type_name:
                continue  # qualified (Alias.Type): stub the module instead
            d = Path(QUrl(url).toLocalFile()).parent
            stub = d / f"{type_name}.qml"
            real = [p for p in REPO.glob(f"**/{type_name}.qml")
                    if not p.relative_to(REPO).parts[0] in ("tests", ".cache", "node_modules")]
            if real and not stub.exists():
                raise AssertionError(
                    f"{type_name} is not a type in {QUrl(url).toLocalFile()}, but it exists in the repo "
                    f"({', '.join(str(p.relative_to(REPO)) for p in real)}): copy it with h.copy() or "
                    f"stub it explicitly with h.stub()/h.module() instead of relying on auto-stubs\n{errors}")
            if not stub.exists():
                stub.write_text("import QtQuick\nItem {}\n")
                self._stubbed.add(stub)
                self._register(stub)
                changed = True
        for url, line, col, prop in _NO_PROP.findall(errors):
            type_name = self._enclosing_type(Path(QUrl(url).toLocalFile()), int(line), int(col))
            stub = Path(QUrl(url).toLocalFile()).parent / f"{type_name}.qml"
            if stub in self._stubbed:
                decl = (f"signal {prop[2].lower()}{prop[3:]}()" if re.match(r"on[A-Z]", prop)
                        else f"property var {prop}")
                body = stub.read_text()
                if decl not in body:
                    stub.write_text(body.replace("Item {", f"Item {{ {decl};", 1))
                    self.auto_stubs.append(f"{type_name}.{prop}")
                    changed = True
        for name in _NO_MODULE.findall(errors):
            d = self.root / name.replace(".", "/")
            if not (d / "qmldir").exists():
                # Qt treats a module without types as "not installed".
                self.module(name, {"HarnessPlaceholder": "QtObject {}"})
                self.auto_stubs.append(f"module {name}")
                print(f"qmlharness: auto-stubbed empty module {name}", file=sys.stderr)
                changed = True
        return changed

    def _register(self, stub: Path) -> None:
        self.auto_stubs.append(stub.stem)
        print(f"qmlharness: auto-stubbed type {stub.stem} in {stub.parent.relative_to(self.root)}/",
              file=sys.stderr)
        qmldir = stub.parent / "qmldir"
        if qmldir.exists():
            first = qmldir.read_text().splitlines()[0]
            self._write_qmldir(stub.parent, first.split()[1])

    @staticmethod
    def _enclosing_type(path: Path, line: int, col: int) -> str:
        """Type name of the innermost object enclosing line:col (1-based)."""
        lines = path.read_text().split("\n")
        text = "\n".join(lines[:line - 1] + [lines[line - 1][:col - 1]])
        depth = 0
        for i in range(len(text) - 1, -1, -1):
            if text[i] == "}":
                depth += 1
            elif text[i] == "{":
                if depth == 0:
                    m = re.search(r"([A-Z]\w*)\s*$", text[:i])
                    return m.group(1) if m else ""
                depth -= 1
        return ""

    # ------------------------------------------------------------ access
    def eval(self, obj: QObject, expr: str):
        e = QQmlExpression(self.engine.contextForObject(obj), obj, expr)
        r = e.evaluate()
        assert not e.hasError(), e.error().toString()
        return r[0] if isinstance(r, tuple) else r

    def find(self, obj: QObject, object_name: str) -> QObject:
        found = obj.findChild(QObject, object_name)
        assert found is not None, f"no child with objectName {object_name!r}"
        return found
