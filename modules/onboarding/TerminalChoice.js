.pragma library

// Pure helpers of the onboarding terminal step (StepTerminal) and its
// summary card (tests/onboarding-terminal.test.cjs): what is preselected on
// a first run, what Continue applies, and how far "fish as the login
// shell" got.
//
// A first run preselects "use this prompt" and "make fish my default
// shell", so clicking through ends with a working prompt in new terminals.
// Nothing is preselected when the user has a prompt of their own (a fish
// file starts starship / oh-my-posh), a login shell of their own (other
// than the distribution's bash / sh), on a re-run of the wizard, or before
// the terminal status is known. fish as the login shell is not preselected
// either when bash login files hold content of the user's own (term.status
// loginFiles: a console login may start the compositor or export variables
// there, and fish reads none of them). "Show system info when a terminal
// opens" (the fastfetch greeting) is preselected on a first run unless it
// is on already, a shell of the user's runs a fetch tool itself, or
// fastfetch can neither be found nor installed. The ticks are applied only by
// Continue.

var PLAIN_SHELLS = ["bash", "sh"];

function _base(path) {
    var s = String(path || "");
    return s.slice(s.lastIndexOf("/") + 1);
}

// fish can be had: installed, or the catalog can install it here.
function fishReachable(status, fishCard) {
    return !!(status && status.fishInstalled) || fishCard !== "unavailable";
}

// The greeting can run here: fastfetch is installed or the catalog can
// install it, and no shell of the user's runs a fetch tool already.
function fetchReachable(status, fetchCard) {
    var g = status ? status.greeting : null;
    if (!g)
        return false;
    var foreign = (g.shells || []).some(function (s) {
        return s && s.state === "foreign";
    });
    return !foreign && (!!g.fastfetchInstalled || (!!fetchCard && fetchCard !== "unavailable"));
}

// The look the wizard turns the greeting on with: the user's own fastfetch
// config when there is one, else the sakura look (and logo).
function fetchLook(status) {
    var g = status ? status.greeting : null;
    return g && g.ownConfig ? "own" : "sakura";
}

// ctx: {firstRun, status (term.status), promptOn, fishCard (ExtrasService
// cardState of "fish"), greetingOn, fetchCard (cardState of "fastfetch")}
// -> {prompt, fish, fetch, known, loginFiles}. known: the status is there
// (defaults are decided once, then remembered); loginFiles: fish was held
// back for the user's bash login files alone.
function defaults(ctx) {
    var st = ctx ? ctx.status : null;
    var out = {
        "prompt": false,
        "fish": false,
        "fetch": false,
        "known": !!st,
        "loginFiles": false
    };
    if (!st || !ctx.firstRun)
        return out;
    out.fetch = !ctx.greetingOn && fetchReachable(st, ctx.fetchCard);
    if (st.foreignPromptInit)
        return out;
    var fishLogin = !!st.fishIsLoginShell;
    var plain = PLAIN_SHELLS.indexOf(_base(st.loginShell)) >= 0;
    var reachable = fishReachable(st, ctx.fishCard);
    var own = heldLoginFiles(st).length > 0;
    out.fish = !fishLogin && plain && reachable && !own;
    out.loginFiles = !fishLogin && plain && reachable && own;
    out.prompt = !ctx.promptOn && reachable && (fishLogin || plain);
    return out;
}

// The bash login files with content of the user's own (term.status
// loginFiles), [] when unknown.
function heldLoginFiles(status) {
    var files = status ? status.loginFiles : null;
    return Array.isArray(files) ? files : [];
}

// What Continue applies: a subset of ["prompt", "fish", "fetch"]. choice:
// {prompt, fish, fetch} as ticked; ctx: {status, promptOn, fishCard, login,
// greetingOn} (login: loginState()).
function actions(choice, ctx) {
    var out = [];
    var st = ctx.status || {};
    if (choice.prompt && !ctx.promptOn)
        out.push("prompt");
    if (choice.fish && !st.fishIsLoginShell && ctx.login !== "pending" && fishReachable(st, ctx.fishCard))
        out.push("fish");
    if (choice.fetch && !ctx.greetingOn)
        out.push("fetch");
    return out;
}

// The extras jobs that change the login shell (backend KindLogin, a
// privileged chsh), from ExtrasService.jobs (job id -> progress).
var LOGIN_KIND = "loginshell";
function loginJobs(jobs) {
    return Object.keys(jobs || {}).map(function (k) {
        return jobs[k];
    }).filter(function (j) {
        return j && j.kind === LOGIN_KIND;
    });
}

// How far fish as the login shell got: "ok" (it is the login shell),
// "pending" (the fish install or the chsh is queued / running), "failed"
// (asked, and the install or the chsh failed or the password was
// cancelled), "none" (not asked), "unknown" (not asked, no status yet).
// asked: the step applied it; fishCard: cardState("fish"); loginJobs:
// loginJobs().
function loginState(status, asked, fishCard, loginJobs) {
    if (status && status.fishIsLoginShell)
        return "ok";
    var jobs = loginJobs || [];
    var running = jobs.some(function (j) {
        return j && (j.state === "queued" || j.state === "running");
    });
    if (fishCard === "installing" || running)
        return "pending";
    if (!asked)
        return status ? "none" : "unknown";
    var failed = jobs.some(function (j) {
        return j && j.state === "failed";
    });
    return failed || fishCard === "failed" ? "failed" : "pending";
}

// The prompt part of the summary card: "" (off), "on" (fish is the login
// shell, or nothing is known yet), "pending", "fish_only" (fish is not the
// login shell: the prompt shows only where fish is started by hand) or
// "failed" (the login shell change did not happen).
function promptOutcome(promptOn, login) {
    if (!promptOn)
        return "";
    if (login === "ok" || login === "unknown")
        return "on";
    if (login === "pending" || login === "failed")
        return login;
    return "fish_only";
}
