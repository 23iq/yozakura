.pragma library

// Pure keyboard helpers (tests/keyboard-model.test.cjs).

// `us` shows as EN, anything else as its upper-cased layout code.
function shortName(layout) {
    var code = String(layout || "").toLowerCase();
    return code === "us" ? "EN" : code.toUpperCase();
}
