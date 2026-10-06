//@ pragma UseQApplication
//@ pragma ShellId yozakura-dryrun
//@ pragma DataDir $BASE/yozakura
//@ pragma StateDir $BASE/yozakura

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.modules.services
import qs.modules.onboarding
import qs.modules.shell
import qs.modules.theme
import qs.config
import "modules/onboarding/OnboardingSteps.js" as Steps

// `<app> onboarding --dry-run` (backend/cmd/yozakura/cmds_onboarding_dryrun.go):
// a separate Quickshell instance with only the setup wizard, its peek pill
// and the display keep/revert prompt. Every change is mocked and journaled
// (DryRun, BackendService); config writes land in the CLI's temp copy. Quits
// when the wizard finishes or is skipped. Refuses to run outside that
// sandbox: nothing (Config included) loads until the real paths of the
// config, cache and state dirs are checked to be inside <PREFIX>DRYRUN_DIR.
ShellRoot {
    id: root

    readonly property int bundledFonts: FontRegistry.count
    // The dirs it writes resolve (symlinks followed) inside the dry-run dir.
    property bool verified: false
    property bool opened: false
    readonly property int openTimeout: 20000

    // The journal file is only written once the sandbox is verified.
    function refuse(reason) {
        console.error("onboarding-dryrun.qml:", reason, "- run it with `" + Brand.appId + " onboarding --dry-run`");
        if (root.verified)
            DryRun.journal("stopped: " + reason);
        Qt.quit();
    }

    // realpath of [dry-run dir, config dir, cache dir, state dir]: exactly
    // <dir>/config/<app>, <dir>/cache/<app>, <dir>/state/<app> (the CLI layout).
    function checkPaths(text) {
        const p = String(text).split("\n").filter(l => l !== "");
        const want = p.length === 4 && p[0] !== "/" ? ["config", "cache", "state"].map(d => p[0] + "/" + d + "/" + Brand.appId) : [];
        const bad = want.length === 3 ? p.slice(1).filter((d, i) => d !== want[i]) : p;
        if (want.length === 3 && bad.length === 0)
            root.verified = true;
        else
            root.refuse("not a dry-run sandbox: " + (bad.join(", ") || "no dry-run dir"));
    }

    Process {
        id: realpaths
        command: ["realpath", "-m", "--", DryRun.dir, Brand.configDir, Brand.cacheDir, Quickshell.statePath("")]
        stdout: StdioCollector {
            onStreamFinished: root.checkPaths(text)
        }
    }

    Loader {
        active: root.verified
        sourceComponent: Scope {
            id: wizardScope

            readonly property bool ready: Config.initialLoadComplete
            property bool started: false

            DryRunWallpapers {
                id: wallpapers
                Component.onCompleted: GlobalStates.wallpaperManager = wallpapers
            }

            Loader {
                active: OnboardingService.visible
                source: "modules/onboarding/OnboardingWindow.qml"
            }
            Loader {
                active: OnboardingService.visible && OnboardingService.peek
                source: "modules/onboarding/OnboardingPeekPill.qml"
            }

            Variants {
                model: Quickshell.screens

                DisplayOverlays {}
            }

            // Config loaded and the compositor state in: open on the focused screen.
            Timer {
                interval: 400
                running: wizardScope.ready && !wizardScope.started
                onTriggered: {
                    wizardScope.started = true;
                    OnboardingService.openAt(Steps.at(0).id);
                    console.info("[dry-run] setup wizard open on", OnboardingService.screenName);
                }
            }
        }
    }

    // Wizard shown: remember it; closed (finished or skipped): quit. The
    // service is only touched once the sandbox is verified.
    Connections {
        target: root.verified ? OnboardingService : null
        function onVisibleChanged() {
            if (OnboardingService.visible)
                root.opened = true;
            else if (root.opened)
                Qt.quit();
        }
    }

    // Never hang invisibly: no wizard after a while ends the run.
    Timer {
        interval: root.openTimeout
        running: DryRun.active && !root.opened
        onTriggered: root.refuse("the setup wizard did not open within " + root.openTimeout / 1000 + " s")
    }

    Component.onCompleted: {
        if (!DryRun.active || DryRun.dir === "")
            root.refuse("not started as a dry run");
        else
            realpaths.running = true;
    }
}
