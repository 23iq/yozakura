// Onboarding terminal step defaults (modules/onboarding/TerminalChoice.js):
// what a first run preselects, what Continue applies, how far the login
// shell change got and what the summary may claim.
const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");
const { loadLibrary } = require("./lib/qmljs.cjs");

const C0 = loadLibrary(path.join(__dirname, "../modules/onboarding/TerminalChoice.js"));
// results cross a VM boundary: compare them as plain JSON values
const plain = v => JSON.parse(JSON.stringify(v));
const C = Object.fromEntries(Object.entries(C0).map(([k, f]) => [k, typeof f === "function" ? (...a) => plain(f(...a)) : f]));

const fresh = { fishInstalled: false, fishIsLoginShell: false, loginShell: "/bin/bash", foreignPromptInit: false };

test("a first run on a plain bash preselects the prompt and fish", () => {
    const d = C.defaults({ firstRun: true, status: fresh, promptOn: false, fishCard: "selectable" });
    assert.deepStrictEqual([d.prompt, d.fish, d.known], [true, true, true]);
});

test("nothing is preselected without a status, on a re-run, or with a prompt or shell of the user's own", () => {
    assert.deepStrictEqual(C.defaults({ firstRun: true, status: null }), { prompt: false, fish: false, known: false, loginFiles: false });
    for (const ctx of [
        { firstRun: false, status: fresh },
        { firstRun: true, status: { ...fresh, foreignPromptInit: true } },
        { firstRun: true, status: { ...fresh, loginShell: "/usr/bin/zsh" } },
        { firstRun: true, status: { ...fresh, loginShell: "" } },
    ]) {
        const d = C.defaults({ promptOn: false, fishCard: "selectable", ...ctx });
        assert.deepStrictEqual([d.prompt, d.fish], [false, false], JSON.stringify(ctx));
    }
});

test("fish that cannot be installed here is not preselected; one already the login shell only needs the prompt", () => {
    const d = C.defaults({ firstRun: true, status: fresh, promptOn: false, fishCard: "unavailable" });
    assert.deepStrictEqual([d.prompt, d.fish], [false, false]);
    const f = C.defaults({ firstRun: true, status: { ...fresh, fishInstalled: true, fishIsLoginShell: true, loginShell: "/usr/bin/fish" }, promptOn: false, fishCard: "installed" });
    assert.deepStrictEqual([f.prompt, f.fish], [true, false]);
    const on = C.defaults({ firstRun: true, status: fresh, promptOn: true, fishCard: "selectable" });
    assert.deepStrictEqual([on.prompt, on.fish], [false, true]);
});

test("bash login files of the user's own hold fish back, not the prompt", () => {
    const own = { ...fresh, loginFiles: ["~/.bash_profile"] };
    const d = C.defaults({ firstRun: true, status: own, promptOn: false, fishCard: "selectable" });
    assert.deepStrictEqual([d.prompt, d.fish, d.loginFiles], [true, false, true]);
    // a zsh user's files: nothing was going to be preselected anyway
    const z = C.defaults({ firstRun: true, status: { ...own, loginShell: "/usr/bin/zsh" }, promptOn: false, fishCard: "selectable" });
    assert.deepStrictEqual([z.fish, z.loginFiles], [false, false]);
    assert.deepStrictEqual(C.heldLoginFiles(own), ["~/.bash_profile"]);
    assert.deepStrictEqual(C.heldLoginFiles(null), []);
    assert.deepStrictEqual(C.heldLoginFiles({ loginFiles: "x" }), []);
});

test("Continue applies what is ticked and still to do", () => {
    const ctx = { status: fresh, promptOn: false, fishCard: "selectable", login: "none" };
    assert.deepStrictEqual(C.actions({ prompt: true, fish: true }, ctx), ["prompt", "fish"]);
    assert.deepStrictEqual(C.actions({ prompt: false, fish: true }, ctx), ["fish"]);
    assert.deepStrictEqual(C.actions({ prompt: false, fish: false }, ctx), []);
    assert.deepStrictEqual(C.actions({ prompt: true, fish: true }, { ...ctx, promptOn: true, login: "pending" }), []);
    assert.deepStrictEqual(C.actions({ prompt: true, fish: true }, { ...ctx, fishCard: "unavailable" }), ["prompt"]);
});

test("login state: pending while it runs, failed after a cancelled password", () => {
    assert.strictEqual(C.loginState(fresh, false, "selectable", []), "none");
    assert.strictEqual(C.loginState(null, false, "selectable", []), "unknown");
    assert.strictEqual(C.loginState(null, true, "selectable", []), "pending");
    assert.strictEqual(C.loginState(fresh, true, "installing", []), "pending");
    assert.strictEqual(C.loginState(fresh, true, "installed", [{ kind: "login", state: "running" }]), "pending");
    assert.strictEqual(C.loginState(fresh, true, "installed", [{ kind: "login", state: "failed", reason: "auth_cancelled" }]), "failed");
    assert.strictEqual(C.loginState(fresh, true, "failed", []), "failed");
    assert.strictEqual(C.loginState({ ...fresh, fishIsLoginShell: true }, true, "installed", [{ state: "failed" }]), "ok");
});

test("login jobs are the chsh jobs of the extras queue", () => {
    const jobs = { a: { kind: "loginshell", state: "failed" }, b: { kind: "system", state: "failed" }, c: null };
    assert.deepStrictEqual(C.loginJobs(jobs), [{ kind: "loginshell", state: "failed" }]);
    assert.deepStrictEqual(C.loginJobs(null), []);
});

test("the summary never claims the prompt for a shell that does not load it", () => {
    assert.strictEqual(C.promptOutcome(false, "ok"), "");
    assert.strictEqual(C.promptOutcome(true, "ok"), "on");
    assert.strictEqual(C.promptOutcome(true, "unknown"), "on");
    assert.strictEqual(C.promptOutcome(true, "pending"), "pending");
    assert.strictEqual(C.promptOutcome(true, "failed"), "failed");
    assert.strictEqual(C.promptOutcome(true, "none"), "fish_only");
});
