pragma Singleton
import QtQuick
import Quickshell
import qs.config
import "HostRouter.js" as Routes

// Maps layout.launcher.host / layout.dashboard.host to a surface host
// ("notch" | "spotlight" | "sheet"). Keybinds, IPC and the Visibilities flags
// are unchanged: a flag says a module is open on a screen, the router says
// which host shows it. Unknown hosts fall back to the notch (logged once).
Singleton {
    id: root

    readonly property var layout: Config.layout ?? null
    readonly property string launcherHost: Routes.hostFor(root.layout, "launcher")
    readonly property string dashboardHost: Routes.hostFor(root.layout, "dashboard")

    property var _warned: ({})

    function hostFor(module: string): string {
        return Routes.hostFor(root.layout, module);
    }

    // The open module of `vis` (Visibilities.getForScreen) shown by `host`.
    function moduleIn(vis: var, host: string): string {
        return Routes.moduleIn(vis, root.layout, host);
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
