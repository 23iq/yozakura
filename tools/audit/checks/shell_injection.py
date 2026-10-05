"""Shell / QML injection guard for QML and JS.

Data must reach a child process as argv, never as code. This check fails on:

  * ``Qt.createQmlObject(src, ...)`` whose source is built with ``+``,
    template interpolation (``${}``) or ``.arg()``: the QML parser undoes any
    escaping, so a file name or config value becomes QML code. Create a
    static ``Component`` (or ``Process {}`` and set ``command`` afterwards).
  * a shell ``-c`` script (``["sh", "-c", script, ...]``, also ``bash``,
    ``-lc`` ...) built with ``+`` / ``${}`` / ``.arg()`` / ``.join()``: pass
    data as positional parameters instead,
    ``["sh", "-c", 'cmd "$1"', "name", value]``.
  * a string literal containing ``sh -c`` inside an expression that
    concatenates or interpolates (``"kitty -e sh -c '" + x + "'"``).

Intentional cases (a user-configured command that *is* a shell script, or a
constant-only expression) go in config.json ``shellInjection.allow`` as
``"<file>::<substring of the flagged expression>": "<reason>"``. An entry
without a reason is an error; an entry that no longer matches is a warning.
"""
from __future__ import annotations

import re
import subprocess

from lib.model import ERROR, REPO, WARN, Issue

CHECK = "shell-injection"

_SHELL_BEFORE = re.compile(r"""["'](?:/[\w/]*/)?(?:ba|z|da|k)?sh["']\s*,\s*$""")
_DASH_C = re.compile(r"^-[a-z]*c$")
_SH_C_TEXT = re.compile(r"(?:^|[\s(;&|])(?:ba|z|da)?sh\s+-[a-z]*c(?:\s|$)")
_BUILD_CALL = re.compile(r"\.(?:arg|join|concat|replace|replaceAll)\s*\(")
_REGEX_PREV = set("(,=:[!&|?{};+-*%<>~^") | {""}
_REGEX_KEYWORDS = ("return", "typeof", "case", "in", "of", "void", "delete")


class _Lexer:
    """Just enough of a JS lexer to tell code from strings and comments."""

    def __init__(self, text: str):
        self.text = text
        self.n = len(text)

    def _prev_sig(self, i: int) -> str:
        j = i - 1
        while j >= 0 and self.text[j] in " \t\r\n":
            j -= 1
        if j < 0:
            return ""
        if self.text[j].isalnum() or self.text[j] in "_$":
            k = j
            while k >= 0 and (self.text[k].isalnum() or self.text[k] in "_$"):
                k -= 1
            word = self.text[k + 1:j + 1]
            return "(" if word in _REGEX_KEYWORDS else "a"
        return self.text[j]

    def skip_string(self, i: int) -> int:
        """i at an opening quote; returns the index after the closing quote."""
        q = self.text[i]
        i += 1
        while i < self.n:
            c = self.text[i]
            if c == "\\":
                i += 2
                continue
            if q == "`" and c == "$" and self.text.startswith("${", i):
                i = self.skip_expr(i + 2, "}")
                continue
            if c == q:
                return i + 1
            i += 1  # QML accepts multi-line '...' and "..." literals
        return i

    def skip_regex(self, i: int) -> int:
        i += 1
        in_class = False
        while i < self.n:
            c = self.text[i]
            if c == "\\":
                i += 2
                continue
            if c == "\n":
                return i
            if c == "[":
                in_class = True
            elif c == "]":
                in_class = False
            elif c == "/" and not in_class:
                i += 1
                while i < self.n and self.text[i].isalpha():
                    i += 1
                return i
            i += 1
        return i

    def skip_comment(self, i: int) -> int | None:
        if self.text.startswith("//", i):
            j = self.text.find("\n", i)
            return self.n if j < 0 else j
        if self.text.startswith("/*", i):
            j = self.text.find("*/", i + 2)
            return self.n if j < 0 else j + 2
        return None

    def skip_expr(self, i: int, closer: str) -> int:
        """Skip to the matching closer (index after it)."""
        depth = 0
        while i < self.n:
            c = self.text[i]
            end = self.skip_comment(i)
            if end is not None:
                i = end
                continue
            if c in "'\"`":
                i = self.skip_string(i)
                continue
            if c == "/" and self._prev_sig(i) in _REGEX_PREV | {"("}:
                i = self.skip_regex(i)
                continue
            if c in "([{":
                depth += 1
            elif c in ")]}":
                if depth == 0:
                    return i + 1 if c == closer else i
                depth -= 1
            i += 1
        return i

    def _statement_ends(self, i: int, last: str) -> bool:
        """At a newline: does the statement end here (no `;` in QML style)?"""
        if not last or last in "+-*/%=<>!&|?:,.([{":
            return False
        j = i
        while j < self.n and self.text[j] in " \t\r\n":
            j += 1
        return j >= self.n or self.text[j] not in "+-*/%=<>&|?:.,)]}"

    def expression(self, i: int) -> tuple[int, dict]:
        """Read one argument/element starting at i; stop at a top-level `,`
        or an unmatched closer. Returns (end, facts)."""
        facts = {"plus": False, "interp": False, "build": False, "strings": [], "code": []}
        depth = 0
        last = ""  # last significant character ('"' after a literal)
        while i < self.n:
            c = self.text[i]
            end = self.skip_comment(i)
            if end is not None:
                i = end
                continue
            if c in "'\"`":
                end = self.skip_string(i)
                lit = self.text[i:end]
                if c == "`" and "${" in lit:
                    facts["interp"] = True
                facts["strings"].append(lit)
                i = end
                last = '"'
                continue
            if c == "/" and self._prev_sig(i) in _REGEX_PREV:
                i = self.skip_regex(i)
                last = ")"
                continue
            if depth == 0 and (c == ";" or (c == "\n" and self._statement_ends(i, last))):
                break
            if not c.isspace():
                last = c
            if c in "([{":
                depth += 1
            elif c in ")]}":
                if depth == 0:
                    break
                depth -= 1
            elif c == "," and depth == 0:
                break
            elif c == "+":
                facts["plus"] = True
            facts["code"].append(c)
            i += 1
        code = "".join(facts["code"])
        facts["build"] = bool(_BUILD_CALL.search(code))
        return i, facts

    def regions(self):
        """Yield (kind, start, end) for every comment and string literal."""
        i = 0
        while i < self.n:
            end = self.skip_comment(i)
            if end is not None:
                yield "comment", i, end
                i = end
                continue
            c = self.text[i]
            if c in "'\"`":
                end = self.skip_string(i)
                yield "string", i, end
                i = end
                continue
            if c == "/" and self._prev_sig(i) in _REGEX_PREV:
                i = self.skip_regex(i)
                continue
            i += 1


def _line(text: str, i: int) -> int:
    return text.count("\n", 0, i) + 1


def _snippet(text: str, a: int, b: int) -> str:
    return " ".join(text[a:b].split())


_IDENT = re.compile(r"^[A-Za-z_$][\w$]*$")


def _resolve_variable(lx: _Lexer, text: str, name: str, before: int) -> dict | None:
    """For `"-c", cmd` with a local `cmd`, check how `cmd` was built: the
    last `cmd = ...` before the use, plus any later `cmd += ...`."""
    if not _IDENT.match(name):
        return None
    facts = None
    for m in re.finditer(r"(?<![\w$.])" + re.escape(name) + r"\s*(\+?=)(?!=)", text[:before]):
        end, f = lx.expression(m.end())
        f["src"] = name + " " + m.group(1) + " " + _snippet(text, m.end(), end)
        if m.group(1) == "=" or facts is None:
            facts = f
        else:  # cmd += ...: concatenation by definition
            facts = {**facts, "plus": True, "src": f["src"]}
    return facts


def scan_text(text: str) -> list[tuple[int, str, str]]:
    """Return (line, kind, expression) for every finding in a QML/JS source."""
    lx = _Lexer(text)
    found: list[tuple[int, str, str]] = []
    seen_spans: list[tuple[int, int]] = []
    regions = list(lx.regions())
    hidden = [(a, b) for _, a, b in regions]

    for m in re.finditer(r"\bcreateQmlObject\s*\(", text):
        if any(a <= m.start() < b for a, b in hidden):
            continue
        start = m.end()
        end, f = lx.expression(start)
        if f["plus"] or f["interp"] or f["build"]:
            found.append((_line(text, m.start()), "createQmlObject", _snippet(text, start, end)))

    for kind, a, b in regions:
        if kind != "string":
            continue
        lit = text[a:b]
        body = lit[1:-1]
        if _DASH_C.match(body) and _SHELL_BEFORE.search(text[max(0, a - 80):a]):
            j = b
            while j < len(text) and text[j] in " \t\r\n":
                j += 1
            if j >= len(text) or text[j] != ",":
                continue
            start = j + 1
            end, f = lx.expression(start)
            if not (f["plus"] or f["interp"] or f["build"]):
                f = _resolve_variable(lx, text, text[start:end].strip(), start) or f
            if f["plus"] or f["interp"] or f["build"]:
                found.append((_line(text, a), "sh -c", f.get("src") or _snippet(text, start, end)))
                seen_spans.append((start, end))
        elif _SH_C_TEXT.search(body) and not any(s <= a < e for s, e in seen_spans):
            # Expression around the literal: from the previous separator.
            k = a
            depth = 0
            while k > 0:
                ch = text[k - 1]
                if ch in ")]}":
                    depth += 1
                elif ch in "([{":
                    if depth == 0:
                        break
                    depth -= 1
                elif ch in ",;=:" and depth == 0:
                    break
                k -= 1
            end, f = lx.expression(k)
            if f["plus"] or f["interp"] or f["build"]:
                found.append((_line(text, a), "sh -c string", _snippet(text, k, end)))
    return found


def _files() -> list[str]:
    out = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard"],
                         cwd=REPO, capture_output=True, text=True, check=True).stdout
    return sorted(f for f in set(out.splitlines())
                  if f.endswith((".qml", ".js")) and not f.startswith(("tests/", "tools/", "backend/"))
                  and "node_modules/" not in f and (REPO / f).is_file())


def run(cfg: dict) -> list[Issue]:
    c = cfg.get("shellInjection", {})
    allow: dict[str, str] = c.get("allow", {})
    issues: list[Issue] = []
    used: set[str] = set()
    for key, reason in allow.items():
        if "::" not in key or not str(reason).strip():
            issues.append(Issue(CHECK, ERROR, f"allowlist entry needs '<file>::<substring>' and a reason: {key!r}",
                                file="tools/audit/config.json", key=key))
    for rel in _files():
        text = (REPO / rel).read_text(encoding="utf-8", errors="replace")
        if "createQmlObject" not in text and "-" not in text:
            continue
        for line, kind, expr in scan_text(text):
            hit = next((k for k, r in allow.items() if str(r).strip() and k.split("::", 1)[0] == rel
                        and k.split("::", 1)[1] in expr), None)
            if hit:
                used.add(hit)
                continue
            what = ("QML source built from data; use a static Component/Process and set properties"
                    if kind == "createQmlObject" else
                    "shell script built from data; pass values as positional args (\"$1\")")
            issues.append(Issue(CHECK, ERROR, f"{kind}: {what}: {expr[:140]}", file=rel, line=line, key=rel))
    for key in allow:
        if key not in used and "::" in key:
            issues.append(Issue(CHECK, WARN, f"stale allowlist entry (no longer matches): {key}",
                                file="tools/audit/config.json", key=key))
    return issues
