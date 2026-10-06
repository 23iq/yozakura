pragma Singleton
import QtQuick
import Quickshell
import qs.config
import "HostRouter.js" as Routes

// Maps layout.launcher.host / layout.dashboard.host to a surface host
// ("notch" | "spotlight" | "sheet"), layout.cheatsheet.host (fullscreen too)
// and layout.powermenu/tools.style ("overlay" off the notch). Keybinds, IPC
// and the Visibilities flags are unchanged: a flag says a module is open on a
// screen, the router says which host shows it. Unknown hosts fall back to the notch (logged once).
Singleton {
    id: root

    readonly property var layout: Config.layout ?? null
    readonly property string launcherHost: Routes.hostFor(root.layout, "launcher")
    readonly property string dashboardHost: Routes.hostFor(root.layout, "dashboard")
    readonly property string cheatsheetHost: Routes.hostFor(root.layout, "cheatsheet")
    readonly property string powermenuStyle: Routes.menuStyle(root.layout, "powermenu")
    readonly property string toolsStyle: Routes.menuStyle(root.layout, "tools")

    property var _warned: ({})

    function hostFor(module: string): string {
        return Routes.hostFor(root.layout, module);
    }

    // The open module of `vis` (Visibilities.getForScreen) shown by `host`.
    function moduleIn(vis: var, host: string): string {
        return Routes.moduleIn(vis, root.layout, host);
    }

    // layout.<module>.style of a menu (powermenu, tools); "notch" otherwise.
    function menuStyle(module: string): string {
        return Routes.menuStyle(root.layout, module);
    }

    function notchOpen(vis: var): bool {
        return Routes.notchOpen(vis, root.layout);
    }

    function _check(module: string) {
        const cfg = root.layout ? root.layout[module] : null;
        const raw = cfg ? cfg.host : undefined;
        if (raw === undefined || Routes.isKnown(raw) || root._warned[module + ":" + raw])
            return;
        root._warned[module + ":" + raw] = true;
        console.warn("HostRouter: unknown layout." + module + ".host \"" + raw + "\", using notch");
    }

    onLauncherHostChanged: root._check("launcher")
    onDashboardHostChanged: root._check("dashboard")
    Component.onCompleted: {
        root._check("launcher");
        root._check("dashboard");
    }
}
