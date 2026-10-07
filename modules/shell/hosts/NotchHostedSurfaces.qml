pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.shell.hosts
import qs.modules.widgets.launcher
import qs.modules.widgets.dashboard

// Keep an already-open module routed when its host changes in Config.layout.
// The visibility flags describe the module, so routing must also observe Config.
Item {
    id: root

    required property ShellScreen screen
    required property var vis
    required property var container
    readonly property string routedModule: {
        if (vis && vis.launcher && HostRouter.hostFor("launcher") === "notch")
            return "launcher";
        if (vis && vis.dashboard && HostRouter.hostFor("dashboard") === "notch")
            return "dashboard";
        return "";
    }
    property string currentModule: ""
    // The notch host, for callers that need its open state.
    readonly property NotchHost host: notchHost

    onRoutedModuleChanged: Qt.callLater(sync)
    Component.onCompleted: Qt.callLater(sync)

    // Other paths push and pop the notch stack (power menu, tools, quick
    // ask, notifications); a routed module must end up on top again.
    Connections {
        target: root.container ? root.container.stackView : null

        function onCurrentItemChanged() {
            Qt.callLater(root.sync);
        }
    }

    function sync() {
        // The module is routed here but its view is gone from the top.
        const lost = routedModule !== "" && currentModule === routedModule && !notchHost.onTop;
        if (currentModule === routedModule && !lost)
            return;
        if (notchHost.isOpen)
            notchHost.close();
        currentModule = routedModule;
        const loader = currentModule === "launcher" ? launcher : currentModule === "dashboard" ? dashboard : null;
        if (loader) {
            loader.active = true;
            notchHost.open(loader.item, screen);
        }
    }

    NotchHost {
        id: notchHost
        container: root.container
    }
    Loader {
        id: launcher
        active: false
        sourceComponent: LauncherView {
            visible: false
        }
    }
    Loader {
        id: dashboard
        active: false
        sourceComponent: DashboardView {
            visible: false
            screenName: root.screen.name
        }
    }
}
