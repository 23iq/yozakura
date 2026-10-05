"""Tiny QML/JS lexer: enough to find identifiers, strings, imports and blocks.

Not a parser. It strips comments, separates string literals from code and
tracks line numbers, which is all the audit checks need. Regex literals are
not recognised (they are rare in this codebase and only matter for brace
matching inside JS bodies, which the checks avoid).
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from functools import cache
from pathlib import Path

IDENT = re.compile(r"[A-Za-z_$][\w$]*")
QS_IMPORT = re.compile(r"^\s*import\s+(qs(?:\.[\w]+)*)(?:\s+as\s+(\w+))?\s*;?\s*$", re.M)
PATH_IMPORT = re.compile(r'^\s*\.?import\s+"([^"]+)"(?:\s+as\s+(\w+))?', re.M)


@dataclass
class Scan:
    code: str  # source with comments removed and string bodies blanked (same length/lines)
    strings: list[tuple[int, str]] = field(default_factory=list)  # (line, value)

    def identifiers(self) -> set[str]:
        return set(IDENT.findall(self.code))


def scan_text(src: str) -> Scan:
    out: list[str] = []
    strings: list[tuple[int, str]] = []
    i, n, line = 0, len(src), 1
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if c == "/" and nxt == "/":
            j = src.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif c == "/" and nxt == "*":
            j = src.find("*/", i + 2)
            j = n if j < 0 else j + 2
            chunk = src[i:j]
            out.append(re.sub(r"[^\n]", " ", chunk))
            line += chunk.count("\n")
            i = j
        elif c in "\"'`":
            j, buf = i + 1, []
            while j < n and src[j] != c:
                if src[j] == "\\" and j + 1 < n:
                    buf.append(src[j:j + 2])
                    j += 2
                    continue
                if src[j] == "\n" and c != "`":
                    break
                buf.append(src[j])
                j += 1
            value = "".join(buf)
            strings.append((line, value))
            out.append(c + re.sub(r"[^\n]", " ", value) + (c if j < n else ""))
            line += value.count("\n")
            i = j + 1
        else:
            if c == "\n":
                line += 1
            out.append(c)
            i += 1
    return Scan(code="".join(out), strings=strings)


@cache
def scan_file(path: Path) -> Scan:
    return scan_text(path.read_text(errors="replace"))


def find_block_end(code: str, open_idx: int) -> int:
    """Index of the `}` matching the `{` at open_idx (comments/strings already blanked)."""
    depth = 0
    for k in range(open_idx, len(code)):
        ch = code[k]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return k
    return len(code) - 1


def line_of(code: str, idx: int) -> int:
    return code.count("\n", 0, idx) + 1
