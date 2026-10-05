.pragma library

// Color spec helpers shared by Config.resolveColor and the compositor
// appearance builder. A color spec is either a palette role ("primary"),
// a literal ("#rrggbb", "#aarrggbb", "rgb(...)", "rgba(...)") or either of
// those with an optional alpha suffix: "surfaceBright@0.5", "#ff0000@0.25".
// The suffix multiplies the resolved color's own alpha, so plain specs keep
// resolving exactly as before.

// Returns { base: string, alpha: number|null }. alpha is null when the spec
// has no (valid) suffix; it is clamped to [0, 1] otherwise.
function parse(spec) {
    if (typeof spec !== "string")
        return { base: spec, alpha: null };
    const trimmed = spec.trim();
    const at = trimmed.lastIndexOf("@");
    if (at <= 0)
        return { base: trimmed, alpha: null };
    const alphaText = trimmed.slice(at + 1).trim();
    if (!/^(\d+(\.\d*)?|\.\d+)$/.test(alphaText))
        return { base: trimmed, alpha: null };
    const alpha = Math.max(0, Math.min(1, parseFloat(alphaText)));
    return { base: trimmed.slice(0, at).trim(), alpha: alpha };
}

// Base part of a spec (role or literal) without the alpha suffix.
function baseOf(spec) {
    return parse(spec).base;
}

// Alpha multiplier of a spec, or 1 when there is no suffix.
function alphaOf(spec) {
    const a = parse(spec).alpha;
    return a === null ? 1 : a;
}

// Builds a spec string from a base and an alpha. alpha >= 1 (or invalid)
// drops the suffix so untouched specs stay byte-identical.
function compose(base, alpha) {
    if (typeof alpha !== "number" || !isFinite(alpha) || alpha >= 1)
        return base;
    const clamped = Math.max(0, alpha);
    return base + "@" + String(Math.round(clamped * 1000) / 1000);
}
