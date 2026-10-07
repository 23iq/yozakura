"""Built-in preset sets for tests and renders (mirrors presetsets.cjs).

assets/presets/{layouts,styles,palettes}/<Name> are parts;
assets/presets/sets/<Name>/set.json names one of each, plus optional domain
override files. A set's config = deep merge of layout -> style -> palette ->
set overrides (objects merge, arrays and scalars replace). A folder without
set.json is a legacy self-contained set (old single-folder presets, user
presets)."""
import json
from pathlib import Path

OFFICIAL = Path(__file__).resolve().parents[2] / "assets" / "presets"
KINDS = ("layout", "style", "palette")
KIND_DIRS = {"layout": "layouts", "style": "styles", "palette": "palettes"}


def deep_merge(base, over):
    out = dict(base) if isinstance(base, dict) else {}
    for k, v in (over or {}).items():
        out[k] = deep_merge(out[k], v) if isinstance(v, dict) and isinstance(out.get(k), dict) else v
    return out


def _dirs(d: Path) -> list[str]:
    return sorted(p.name for p in d.iterdir() if p.is_dir()) if d.is_dir() else []


def domains(folder: Path) -> dict:
    """{domain: object} of a folder's *.json, minus info.json and set.json."""
    return {f.stem: json.loads(f.read_text()) for f in sorted(Path(folder).glob("*.json"))
            if f.stem not in ("info", "set")}


def set_root(root: Path = OFFICIAL) -> Path:
    return root / "sets" if (root / "sets").is_dir() else root


def list_sets(root: Path = OFFICIAL) -> list[str]:
    return _dirs(set_root(root))


def list_parts(kind: str, root: Path = OFFICIAL) -> list[str]:
    return _dirs(root / KIND_DIRS[kind])


def part_dir(kind: str, name: str, root: Path = OFFICIAL) -> Path | None:
    want = name.lower()
    hit = next((n for n in list_parts(kind, root) if n.lower() == want), None)
    return None if hit is None else root / KIND_DIRS[kind] / hit


def set_dir(name: str, root: Path = OFFICIAL) -> Path:
    return set_root(root) / name


def compose_folder(folder: Path, root: Path = OFFICIAL) -> dict:
    """{domain: object} of a set folder (legacy: its own files)."""
    folder = Path(folder)
    ref_file = folder / "set.json"
    if not ref_file.exists():
        return domains(folder)
    refs = json.loads(ref_file.read_text())
    out: dict = {}
    sources = []
    for kind in KINDS:
        p = part_dir(kind, refs[kind], root)
        if p is None:
            raise FileNotFoundError(f"{folder.name}: {kind} {refs[kind]!r} not found")
        sources.append(p)
    for src in [*sources, folder]:
        for dom, obj in domains(src).items():
            out[dom] = deep_merge(out.get(dom), obj)
    return out


def compose(name: str, root: Path = OFFICIAL) -> dict:
    return compose_folder(set_dir(name, root), root)


def read(name: str, domain: str, root: Path = OFFICIAL) -> dict:
    """One domain of a composed set ({} when no source has it)."""
    return compose(name, root).get(domain, {})
