// The fastfetch greeting UI helpers (modules/terminal/FetchModel.js), and
// the lists that must agree with the bundled looks and the kitty theme.
const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { loadLibrary } = require("./lib/qmljs.cjs");

const ROOT = path.join(__dirname, "..");
const M0 = loadLibrary(path.join(ROOT, "modules/terminal/FetchModel.js"));
const plain = v => JSON.parse(JSON.stringify(v));
const M = Object.fromEntries(Object.entries(M0).map(([k, f]) => [k, typeof f === "function" ? (...a) => plain(f(...a)) : f]));
const Enums = loadLibrary(path.join(ROOT, "config/meta/Enums.js"));

const PRESETS = [{ id: "sakura", logo: true }, { id: "minimal", logo: false }, { id: "own", logo: false, own: true }];

test("preview keys tell looks, logos and custom files apart", () => {
    assert.strictEqual(M.previewKey("sakura", "distro", "/x.png"), "sakura|distro|");
    assert.strictEqual(M.previewKey("sakura", "custom", "/x.png"), "sakura|custom|/x.png");
    assert.notStrictEqual(M.previewKey("sakura", "custom", "/a"), M.previewKey("sakura", "custom", "/b"));
});

test("the logo choice applies to looks with a logo only", () => {
    assert.strictEqual(M.logoBlocked(M.presetOf(PRESETS, "sakura")), "");
    assert.strictEqual(M.logoBlocked(M.presetOf(PRESETS, "minimal")), "none");
    assert.strictEqual(M.logoBlocked(M.presetOf(PRESETS, "own")), "own");
    assert.strictEqual(M.logoBlocked(M.presetOf(PRESETS, "nope")), "");
});

test("turning the greeting on never ends on plain fastfetch without a config of the user's", () => {
    assert.strictEqual(M.presetOnTurnOn("own", false), "sakura");
    assert.strictEqual(M.presetOnTurnOn("own", true), "own");
    assert.strictEqual(M.presetOnTurnOn("boxed", false), "boxed");
    assert.strictEqual(M.presetOnTurnOn("", false), "sakura");
});

test("shell states and notices", () => {
    const g = { shells: [{ shell: "fish", state: "on" }, { shell: "bash", state: "foreign", file: "/home/u/.bashrc" },
        { shell: "zsh", state: "on" }], logoError: "logo_missing" };
    assert.deepStrictEqual(M.shellsOn(g), ["fish", "zsh"]);
    assert.deepStrictEqual(M.shellsIn(g, "foreign").map(s => s.shell), ["bash"]);
    assert.deepStrictEqual(M.shellsOn(null), []);
    assert.strictEqual(M.tilde("/home/u/.bashrc", "/home/u"), "~/.bashrc");
    assert.strictEqual(M.tilde("/etc/bashrc", "/home/u"), "/etc/bashrc");
    assert.strictEqual(M.logoErrorKey(g), "prefs.term.fetch.logo_error.logo_missing");
    assert.strictEqual(M.logoErrorKey({ logoError: "weird thing" }), "prefs.term.fetch.logo_error.logo_format");
    assert.strictEqual(M.logoErrorKey({}), "");
    assert.strictEqual(M.sampleReason({ exact: true }), "");
    assert.strictEqual(M.sampleReason({ exact: false, reason: "fastfetch_missing" }), "missing");
    assert.strictEqual(M.sampleReason({ exact: false, reason: "timeout" }), "failed");
    assert.strictEqual(M.sampleReason(undefined), "");
});

test("every logo key has its translation, every look its description", () => {
    const en = JSON.parse(fs.readFileSync(path.join(ROOT, "translations/en.json"), "utf8"));
    for (const l of M.logos())
        assert.ok(en["prefs.term.fetch.logo." + l], l);
    const idx = JSON.parse(fs.readFileSync(path.join(ROOT, "assets/terminal/fastfetch/presets.json"), "utf8"));
    for (const p of idx.presets)
        assert.ok(en[p.description], p.description);
    for (const e of ["logo_path", "logo_missing", "logo_not_file", "logo_too_large", "logo_format", "logo_hidden"])
        assert.ok(en["prefs.term.fetch.logo_error." + e], e);
});

test("the catalog enums list the bundled looks and the logos", () => {
    const idx = JSON.parse(fs.readFileSync(path.join(ROOT, "assets/terminal/fastfetch/presets.json"), "utf8"));
    assert.deepStrictEqual([...Enums.TERMINAL_FETCH_PRESETS], idx.presets.map(p => p.id));
    assert.deepStrictEqual([...Enums.TERMINAL_FETCH_LOGOS], M.logos());
    const defaults = loadLibrary(path.join(ROOT, "config/defaults/terminal.js")).data;
    assert.ok(Enums.TERMINAL_FETCH_PRESETS.includes(defaults.fastfetchPreset));
    assert.ok(Enums.TERMINAL_FETCH_LOGOS.includes(defaults.fastfetchLogo));
    // existing installs keep plain fastfetch for a greeting they turned on
    assert.strictEqual(defaults.fastfetchPreset, "own");
    assert.strictEqual(defaults.greeting, "none");
});

test("the preview's 16 colours are the ones the kitty theme writes", () => {
    const src = fs.readFileSync(path.join(ROOT, "modules/theme/KittyGenerator.qml"), "utf8");
    for (let i = 0; i < 16; i++) {
        const m = src.match(new RegExp("const color" + i + " = fmt\\(([^;]*)\\);"));
        assert.ok(m, "color" + i);
        const role = M.ANSI_ROLES[i];
        const want = typeof role === "string" ? "Colors." + role : "dark ? Colors." + role[0] + " : Colors." + role[1];
        assert.strictEqual(m[1].trim(), want, "color" + i);
    }
    const colors = { surfaceContainerHigh: "#111111", overSurface: "#eeeeee", red: "#ff0000", green: "#00ff00",
        yellow: "#ffff00", blue: "#0000ff", magenta: "#ff00ff", cyan: "#00ffff", overSurfaceVariant: "#cccccc",
        outline: "#888888", lightRed: "#ff8888", lightGreen: "#88ff88", lightYellow: "#ffff88", lightBlue: "#8888ff",
        lightMagenta: "#ff88ff", lightCyan: "#88ffff", surfaceContainerLowest: "#ffffff" };
    const dark = M.ansiTable(colors, true);
    assert.strictEqual(dark.length, 16);
    assert.strictEqual(dark[0], "#111111");
    assert.strictEqual(dark[15], "#eeeeee");
    assert.strictEqual(M.ansiTable(colors, false)[0], "#eeeeee");
    assert.strictEqual(M.ansiTable({ ...colors, red: { r: 1, g: 0.5, b: 0 } }, true)[1], "#ff8000");
    assert.deepStrictEqual(M.ansiTable({ red: "#ff0000" }, true), []);
});
