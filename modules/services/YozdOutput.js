.pragma library

// yozd one-shots print some failures (e.g. "Error connecting to daemon:
// ...") on stdout and still exit 0. Only hand text that looks like JSON to
// JSON.parse; report anything else as a readable error instead of throwing
// a bare SyntaxError.
function parse(text) {
    const trimmed = String(text === undefined || text === null ? "" : text).trim();
    if (trimmed === "")
        return { ok: false, value: null, error: "empty output" };
    const first = trimmed.charAt(0);
    if (first !== "{" && first !== "[")
        return { ok: false, value: null, error: trimmed.split("\n")[0] };
    try {
        return { ok: true, value: JSON.parse(trimmed), error: "" };
    } catch (e) {
        return { ok: false, value: null, error: "invalid JSON (" + e.message + ")" };
    }
}
