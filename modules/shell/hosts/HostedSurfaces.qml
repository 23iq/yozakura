pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.services
import qs.modules.shell.hosts
import qs.modules.widgets.dashboard
import qs.modules.widgets.launcher
import qs.modules.keybinds

// Per-screen owner of the spotlight and sheet hosts (launcher, dashboard,
// keybind cheatsheet). Watches this screen's Visibilities flags through
// HostRouter and opens/closes the host that shows the module; hosts and views are created on first use and kept, like the
// notch's persistent views. A host's requestClose clears the flags.
Scope {
    id: root

    required property ShellScreen screen
    readonly property var vis: root.screen ? Visibilities.getForScreen(root.screen.name) : null
    readonly property string spotlightModule: HostRouter.moduleIn(root.vis, "spotlight")
    readonly property string sheetModule: HostRouter.moduleIn(root.vis, "sheet")

    // For tests and callers: the host instances once created.
    readonly property var spotlight: spotlightLoader.item
    readonly property var sheet: sheetLoader.item

    onSpotlightModuleChanged: root.route(spotlightLoader, root.spotlightModule)
    onSheetModuleChanged: root.route(sheetLoader, root.sheetModule)
    Component.onCompleted: {
        root.route(spotlightLoader, root.spotlightModule);
        root.route(sheetLoader, root.sheetModule);
    }

    function viewFor(module: string): var {
        const loader = module === "dashboard" ? dashboardLoader : module === "cheatsheet" ? cheatsheetLoader : launcherLoader;
        loader.active = true;
        return loader.item;
    }

    function route(loader, module: string) {
        if (module === "") {
            if (loader.item)
                loader.item.close();
            return;
        }
        loader.active = true;
        const view = root.viewFor(module);
        if (loader.item && view)
            loader.item.open(view, root.screen);
    }

    function dismiss() {
        Visibilities.setActiveModule("");
    }

    Loader {
        id: launcherLoader
        active: false
        sourceComponent: Component {
            LauncherView {
                visible: false
            }
        }
    }

    Loader {
        id: dashboardLoader
        active: false
        sourceComponent: Component {
            DashboardView {
                visible: false
                screenName: root.screen ? root.screen.name : ""
            }
        }
    }

    Loader {
        id: cheatsheetLoader
        active: false
        sourceComponent: Component {
            CheatsheetView {
                visible: false
                screenName: root.screen ? root.screen.name : ""
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
}
