pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services
import qs.modules.terminal
import qs.modules.components.kit
import qs.config
import "../terminal/TermModel.js" as TermModel
import "TerminalChoice.js" as Choice

// The terminal step's shell choices: "use this prompt in fish", "make
// fish my default shell" and "show system info when a terminal opens" (the
// fastfetch greeting). On a first run the first two are preselected unless
// the user has a prompt or a shell of their own; the greeting is opt-in
// (TerminalChoice.defaults); the ticks are applied only when the user continues past the step (apply(),
// the step's leave guard), never on skip or close. A plain notice says what
// Continue does; a failed or cancelled login-shell change is said plainly.
Column {
    id: root

    property OnboardingState wizard

    readonly property var choices: root.wizard ? root.wizard.choices : ({})
    readonly property var status: TerminalLookService.status
    readonly property bool firstRun: !OnboardingService.done
    readonly property bool promptOn: !!(Config.terminal && Config.terminal.enabled)
    readonly property bool foreign: !!(root.status && root.status.foreignPromptInit)
    readonly property bool fishInstalled: !!(root.status && root.status.fishInstalled)
    readonly property string fishCard: ExtrasService.cardState("fish")
    readonly property bool greetingOn: !!(Config.terminal && Config.terminal.greeting === "fastfetch")
    readonly property bool fetchForeign: !!root.status && !!root.status.greeting && (root.status.greeting.shells || []).some(s => s.state === "foreign")
    readonly property bool tickFetch: root.choices.termFetch === true
    // the greeting was on already (an earlier Continue) and is unticked now
    readonly property bool tickFetchOff: root.choices.termFetchOff === true
    // fish is missing and nothing here can install it: the user does
    readonly property bool fishManual: !!root.status && !root.fishInstalled && root.fishCard === "unavailable"
    readonly property var loginJobs: Choice.loginJobs(ExtrasService.jobs)
    readonly property string login: Choice.loginState(root.status, root.choices.fishDefault === true, root.fishCard, root.loginJobs)
    readonly property bool tickPrompt: root.choices.termPrompt === true
    readonly property bool tickFish: root.choices.termFish === true && root.login !== "failed"
    // bash login files of the user's own: why fish was not preselected
    readonly property var loginFiles: Choice.heldLoginFiles(root.status)
    readonly property var pending: Choice.actions({
        "prompt": root.tickPrompt,
        "fish": root.tickFish,
        "fetch": root.tickFetch,
        "fetchOff": root.tickFetchOff
    }, {
        "status": root.status,
        "promptOn": root.promptOn,
        "fishCard": root.fishCard,
        "login": root.login,
        "greetingOn": root.greetingOn
    })
    // The prompt engine is missing and the catalog has no source for it on
    // this distribution: it must be installed by hand (its package name).
    readonly property string engineId: TermModel.engineExtra(TerminalLookService.engine)
    readonly property bool engineManual: !!root.status && !!root.status.engineInstalled && !root.status.engineInstalled[TerminalLookService.engine] && ExtrasService.cardState(root.engineId) === "unavailable"

    spacing: Space.s

    // First run: preselect once the status is known, then remember.
    function decideDefaults() {
        if (!root.wizard || root.choices.termPrompt !== undefined)
            return;
        const d = Choice.defaults({
            "firstRun": root.firstRun,
            "status": root.status,
            "promptOn": root.promptOn,
            "fishCard": root.fishCard
        });
        if (!d.known)
            return;
        root.wizard.remember("termPrompt", d.prompt);
        root.wizard.remember("termFish", d.fish);
        root.wizard.remember("termFetch", d.fetch);
    }

    // Continue: switch the prompt on and / or make fish the login shell
    // (installs fish first; chsh asks for the password in the background).
    function apply() {
        const todo = root.pending;
        if (todo.includes("prompt") && TerminalLookService.prompt !== "")
            TerminalLookService.enablePrompt(TerminalLookService.prompt);
        if (todo.includes("fish")) {
            TerminalLookService.makeFishDefault();
            root.wizard.remember("fishDefault", true);
        }
        if (todo.includes("fetch"))
            TerminalLookService.enableGreeting(Choice.fetchLook(root.status), "sakura");
        if (todo.includes("fetchOff") && Config.terminal) {
            Config.terminal.greeting = "none";
            Config.saveTerminal();
        }
        return true;
    }

    // Only remembered: Continue applies it (switched on earlier in this
    // wizard and unticked now: off on Continue, never on Skip).
    function setFetch(on) {
        root.wizard.remember("termFetch", on);
        root.wizard.remember("termFetchOff", !on && root.greetingOn);
    }

    function setPrompt(on) {
        root.wizard.remember("termPrompt", on);
        // Switched on earlier (a card click): off now, like Settings does.
        if (!on && root.promptOn && Config.terminal) {
            Config.terminal.enabled = false;
            Config.saveTerminal();
        }
    }

    function setFish(on) {
        root.wizard.remember("termFish", on);
        // ticking it again after a failure asks again on Continue
        if (on)
            root.wizard.remember("fishDefault", false);
    }

    Component.onCompleted: root.decideDefaults()
    Connections {
        target: TerminalLookService
        function onStatusChanged() {
            root.decideDefaults();
        }
    }

    ChoiceRow {
        objectName: "promptOn"
        width: parent.width
        mode: "toggle"
        icon: "sparkle"
        enabled: !root.foreign
        checked: root.promptOn || root.tickPrompt
        title: I18n.t("onboarding.terminal.use_prompt")
        subtitle: I18n.t(root.foreign ? "onboarding.terminal.use_prompt.foreign" : "onboarding.terminal.use_prompt.desc")
        onToggled: v => root.setPrompt(v)
    }

    ChoiceRow {
        objectName: "fishDefault"
        width: parent.width
        mode: "toggle"
        icon: "terminal"
        enabled: root.login !== "ok" && root.login !== "pending" && !root.fishManual
        checked: root.login === "ok" || root.login === "pending" || root.tickFish
        title: I18n.t("onboarding.terminal.fish")
        subtitle: I18n.t(root.login === "ok" ? "onboarding.terminal.fish.ok" : (root.fishManual ? "onboarding.terminal.fish.manual" : (root.fishInstalled ? "onboarding.terminal.fish.desc" : "onboarding.terminal.fish.missing")))
        badge: root.login === "pending" ? I18n.t("prefs.term.look.installing") : ""
        onToggled: v => root.setFish(v)
    }

    ChoiceRow {
        objectName: "fetchOn"
        width: parent.width
        mode: "toggle"
        icon: "info"
        enabled: !root.fetchForeign
        checked: root.greetingOn ? !root.tickFetchOff : root.tickFetch
        title: I18n.t("onboarding.terminal.fetch")
        subtitle: I18n.t(root.fetchForeign ? "onboarding.terminal.fetch.foreign" : (Choice.fetchLook(root.status) === "own" ? "onboarding.terminal.fetch.own" : "onboarding.terminal.fetch.desc"))
        onToggled: v => root.setFetch(v)
    }

    // What Continue does, in plain words.
    LookNotice {
        objectName: "shellPlan"
        width: parent.width
        visible: message !== ""
        tone: "info"
        icon: "info"
        title: I18n.t("onboarding.terminal.plan.title")
        readonly property string shellPart: root.pending.includes("fish") ? I18n.t(root.fishInstalled ? "onboarding.terminal.plan.fish" : "onboarding.terminal.plan.fish_install") : ((root.promptOn || root.pending.includes("prompt")) && root.login === "none" && !(root.status && root.status.fishIsLoginShell) ? I18n.t("onboarding.terminal.plan.prompt_only") : "")
        readonly property string fetchKey: Choice.fetchPlanKey(root.pending, TerminalLookService.fastfetchInstalled)
        message: [shellPart, fetchKey !== "" ? I18n.t(fetchKey) : ""].filter(s => s !== "").join(" ")
    }

    LookNotice {
        objectName: "loginFiles"
        width: parent.width
        visible: root.loginFiles.length > 0 && !root.tickFish && root.login === "none"
        tone: "info"
        icon: "info"
        title: I18n.t("onboarding.terminal.login_files.title")
        message: I18n.t("onboarding.terminal.login_files.desc", root.loginFiles.join(", "))
    }

    LookNotice {
        objectName: "loginFailed"
        width: parent.width
        visible: root.login === "failed"
        tone: "warning"
        icon: "warning"
        title: I18n.t("onboarding.terminal.login_failed.title")
        message: I18n.t("onboarding.terminal.login_failed.desc")
    }

    LookNotice {
        objectName: "engineManual"
        width: parent.width
        visible: root.engineManual && (root.promptOn || root.tickPrompt)
        tone: "warning"
        icon: "downloadSimple"
        title: I18n.t("onboarding.terminal.engine_manual.title", ExtrasService.displayName(root.engineId))
        message: I18n.t("onboarding.terminal.engine_manual.desc", root.engineId)
    }
}
