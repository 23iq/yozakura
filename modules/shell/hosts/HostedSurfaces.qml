pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.services
import qs.modules.shell.hosts
import qs.modules.widgets.dashboard
import qs.modules.widgets.launcher
import qs.modules.keybinds
import qs.modules.aicenter.quickask
import qs.modules.components
import qs.modules.components.kit
import qs.config
import "WarmUp.js" as WarmUp

// Per-screen owner of the spotlight, sheet and card hosts (launcher,
// dashboard, keybind cheatsheet, AI quick ask). Watches this screen's Visibilities flags through
// HostRouter and opens/closes the host that shows the module; hosts and views are created on first use and kept, like the
// notch's persistent views. A host's requestClose clears the flags.
// Views load asynchronously (WarmLoader): the host opens once its view is
// ready, so a first open never freezes the shell, and the launcher view is
// pre-created hidden `warmDelay` ms after startup on the screen it will
// most likely open on (WarmUp.js), unless performance.warmViews is off.
Scope {
    id: root

    required property ShellScreen screen
    readonly property var vis: root.screen ? Visibilities.getForScreen(root.screen.name) : null
    readonly property string spotlightModule: HostRouter.moduleIn(root.vis, "spotlight")
    readonly property string sheetModule: HostRouter.moduleIn(root.vis, "sheet")
    readonly property string cardModule: HostRouter.moduleIn(root.vis, "card")

    // For tests and callers: the host instances once created.
    readonly property var spotlight: spotlightLoader.item
    readonly property var sheet: sheetLoader.item
    readonly property var card: cardLoader.item
    readonly property bool launcherReady: launcherLoader.ready

    onSpotlightModuleChanged: root.route(spotlightLoader, root.spotlightModule)
    onSheetModuleChanged: root.route(sheetLoader, root.sheetModule)
    onCardModuleChanged: root.route(cardLoader, root.cardModule)
    Component.onCompleted: {
        root.route(spotlightLoader, root.spotlightModule);
        root.route(sheetLoader, root.sheetModule);
        root.route(cardLoader, root.cardModule);
    }

    property int warmDelay: 3000

    function viewLoader(module: string): var {
        return module === "dashboard" ? dashboardLoader : module === "cheatsheet" ? cheatsheetLoader : module === "aiquick" ? quickAskLoader : launcherLoader;
    }

    function moduleOf(loader): string {
        return loader === spotlightLoader ? root.spotlightModule : loader === sheetLoader ? root.sheetModule : root.cardModule;
    }

    function route(loader, module: string) {
        if (module === "") {
            if (loader.item)
                loader.item.close();
            return;
        }
        loader.active = true;
        root.viewLoader(module).request(view => {
            // Closed or rerouted while the view was loading
            if (root.moduleOf(loader) !== module)
                return;
            if (loader.item && view)
                loader.item.open(view, root.screen);
        });
    }

    function warmLauncher() {
        if (!WarmUp.enabled(Config.performance))
            return;
        const names = [];
        for (let i = 0; i < Quickshell.screens.length; i++)
            names.push(Quickshell.screens[i].name);
        if (WarmUp.shouldWarm("hosts", HostRouter.hostFor("launcher"), root.screen ? root.screen.name : "", names, Visibilities.lastFocusedScreen))
            launcherLoader.warm();
    }

    Timer {
        interval: root.warmDelay
        running: true
        onTriggered: root.warmLauncher()
    }

    function dismiss() {
        Visibilities.setActiveModule("");
    }

    WarmLoader {
        id: launcherLoader
        sourceComponent: Component {
            LauncherView {
                visible: false
            }
        }
    }

    WarmLoader {
        id: dashboardLoader
        sourceComponent: Component {
            DashboardView {
                visible: false
                screenName: root.screen ? root.screen.name : ""
            }
        }
    }

    WarmLoader {
        id: cheatsheetLoader
        sourceComponent: Component {
            CheatsheetView {
                visible: false
                screenName: root.screen ? root.screen.name : ""
            }
        }
    }

    // AI quick ask off the notch (layout.aiquick.host: card | spotlight)
    WarmLoader {
        id: quickAskLoader
        sourceComponent: Component {
            QuickAskCard {
                visible: false
            }
        }
    }

    Loader {
        id: spotlightLoader
        active: false
        sourceComponent: Component {
            SpotlightHost {
                screen: root.screen
                onRequestClose: root.dismiss()
            }
        }
    }

    Loader {
        id: sheetLoader
        active: false
        sourceComponent: Component {
            SheetHost {
                screen: root.screen
                onRequestClose: root.dismiss()
            }
        }
    }

    Loader {
        id: cardLoader
        active: false
        sourceComponent: Component {
            CardHost {
                screen: root.screen
                padding: Space.m
                onRequestClose: root.dismiss()
            }
        }
    }
}
