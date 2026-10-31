pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.modules.services
import "HostRouter.js" as Routes

// Maps layout.launcher.host / layout.dashboard.host to a surface host
// ("notch" | "spotlight" | "sheet"), layout.cheatsheet.host (fullscreen too)
// and layout.powermenu/tools.style ("overlay" off the notch). The host is
// resolved (HostResolve.js): "auto", an unknown value or the notch while
// notch.enabled is off fall back at runtime; the config is never rewritten.
// Keybinds, IPC and the Visibilities flags are unchanged: a flag says a
// module is open on a screen, the router says which host shows it.
Singleton {
    id: root

    readonly property var layout: Config.layout ?? null
    // HostResolve context (ShellLayout: the composable layout)
    readonly property var ctx: ({
            "notchEnabled": ShellLayout.notchEnabled,
            "barEnabled": ShellLayout.barEnabled,
            "barEdges": ShellLayout.layout.bar.edges
        })
    readonly property string launcherHost: Routes.hostFor(root.layout, "launcher", root.ctx)
    readonly property string dashboardHost: Routes.hostFor(root.layout, "dashboard", root.ctx)
    readonly property string cheatsheetHost: Routes.hostFor(root.layout, "cheatsheet", root.ctx)
    readonly property string powermenuStyle: Routes.menuStyle(root.layout, "powermenu", root.ctx)
    readonly property string toolsStyle: Routes.menuStyle(root.layout, "tools", root.ctx)

    property var _warned: ({})

    function hostFor(module: string): string {
        return Routes.hostFor(root.layout, module, root.ctx);
    }

    // The open module of `vis` (Visibilities.getForScreen) shown by `host`.
    function moduleIn(vis: var, host: string): string {
        return Routes.moduleIn(vis, root.layout, host, root.ctx);
    }

    // Resolved layout.<module>.style of a menu (powermenu, tools); "notch" otherwise.
    function menuStyle(module: string): string {
        return Routes.menuStyle(root.layout, module, root.ctx);
    }

    function notchOpen(vis: var): bool {
        return Routes.notchOpen(vis, root.layout, root.ctx);
    }

    function _check(module: string) {
        const cfg = root.layout ? root.layout[module] : null;
        const raw = cfg ? cfg.host : undefined;
        if (raw === undefined || Routes.isKnown(raw) || root._warned[module + ":" + raw])
            return;
        root._warned[module + ":" + raw] = true;
        console.warn("HostRouter: unknown layout." + module + ".host \"" + raw + "\", using auto");
    }

    onLauncherHostChanged: root._check("launcher")
    onDashboardHostChanged: root._check("dashboard")
    Component.onCompleted: {
        root._check("launcher");
        root._check("dashboard");
    }
}
