pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.shell.hosts
import qs.modules.widgets.powermenu
import qs.modules.widgets.tools
import qs.modules.aicenter.quickask

// The notch's menu views: power menu, tools and AI quick ask. Each view is
// created on first use and kept; while its Visibilities flag is set and
// HostRouter routes it to the notch it is pushed onto the notch stack, and
// popped when the flag clears or it is routed away while open. Routed
// elsewhere (another layout.powermenu/tools.style or layout.aiquick.host)
// the notch never takes it: the menu overlay or the card shows it.
Item {
    id: root

    // This screen's Visibilities object
    required property var vis
    // The Notch: pushView(), stackView, isShowingDefault, isShowingNotifications
    required property var container

    // The module whose view this pushed onto the notch stack ("" = none)
    property string shown: ""

    function loaderOf(module: string): Loader {
        return module === "powermenu" ? powerMenu : module === "tools" ? toolsMenu : quickAsk;
    }

    function sync(module: string) {
        if (!root.vis || !root.container)
            return;
        if (root.vis[module] && HostRouter.hostFor(module) === "notch") {
            root.shown = module;
            root.push(root.loaderOf(module));
        } else if (root.shown === module) {
            root.shown = "";
            root.pop();
        }
    }

    function push(loader: Loader) {
        loader.active = true;
        Qt.callLater(() => {
            if (!loader.item)
                return;
            root.container.pushView(loader.item);
            Qt.callLater(() => {
                const top = root.container.stackView.currentItem;
                if (top)
                    top.forceActiveFocus();
            });
        });
    }

    function pop() {
        if (root.container.stackView.depth <= 1)
            return;
        root.container.stackView.pop();
        root.container.isShowingDefault = true;
        root.container.isShowingNotifications = false;
    }

    // Routed away while open (the host changed under it)
    Connections {
        target: HostRouter

        function onPowermenuStyleChanged() {
            root.sync("powermenu");
        }
        function onToolsStyleChanged() {
            root.sync("tools");
        }
        function onAiquickHostChanged() {
            root.sync("aiquick");
        }
    }

    Connections {
        target: root.vis

        function onPowermenuChanged() {
            root.sync("powermenu");
        }
        function onToolsChanged() {
            root.sync("tools");
        }
        function onAiquickChanged() {
            root.sync("aiquick");
        }
    }

    Loader {
        id: powerMenu
        active: false
        sourceComponent: Component {
            PowerMenuView {
                visible: false
            }
        }
    }

    Loader {
        id: toolsMenu
        active: false
        sourceComponent: Component {
            ToolsMenuView {
                visible: false
            }
        }
    }

    // AI quick ask: a focusable input inside the island; it switches views
    // like the launcher, unlike the registry's panels (NotchPanels.js).
    Loader {
        id: quickAsk
        active: false
        sourceComponent: Component {
            QuickAskCard {
                visible: false
            }
        }
    }
}
