//@ pragma UseQApplication
//@ pragma ShellId yozakura-dryrun
//@ pragma DataDir $BASE/yozakura
//@ pragma StateDir $BASE/yozakura

import QtQuick
import Quickshell
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
// sandbox (no <PREFIX>DRYRUN=1 or the config dir is the real one).
ShellRoot {
    id: root

    readonly property int bundledFonts: FontRegistry.count
    readonly property bool ready: Config.initialLoadComplete

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
        id: openTimer
        interval: 400
        running: root.ready && DryRun.sandboxed
        onTriggered: {
            OnboardingService.openAt(Steps.at(0).id);
            console.info("[dry-run] setup wizard open on", OnboardingService.screenName);
        }
    }

    Connections {
        target: OnboardingService
        function onVisibleChanged() {
            if (!OnboardingService.visible)
                Qt.quit();
        }
    }

    Component.onCompleted: {
        if (!DryRun.sandboxed) {
            console.error("onboarding-dryrun.qml: run it with `" + Brand.appId + " onboarding --dry-run`");
            Qt.quit();
        }
    }
}
