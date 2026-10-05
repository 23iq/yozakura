import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.services

// Desktop applications (AppSearch): every app on an empty search, fuzzy
// matches otherwise. Options: launch, pin to the dock, desktop shortcut.
LauncherProvider {
    id: apps

    mixedLimit: 0

    function compute(text, searchMode) {
        const list = text.length > 0 ? AppSearch.fuzzyQuery(text) : AppSearch.getAllApps();
        return list.map(app => ({
                    "key": app.id,
                    "title": app.name,
                    "subtitle": app.comment || "",
                    "image": app.icon,
                    "hint": I18n.t("launcher.launch"),
                    "data": app
                }));
    }

    function activate(item, option) {
        const app = item.data;
        if (!app)
            return false;
        if (option === "pin") {
            TaskbarApps.togglePin(app.id);
            return false;
        }
        if (option === "shortcut") {
            apps.createShortcut(app);
            return false;
        }
        if (app.execute)
            app.execute();
        UsageTracker.recordUsage(app.id);
        return true;
    }

    function options(item) {
        const pinned = TaskbarApps.isPinned(item.key);
        return [
            {
                "id": "",
                "text": I18n.t("launcher.launch"),
                "icon": Icons.launch,
                "variant": "primary"
            },
            {
                "id": "pin",
                "text": pinned ? I18n.t("launcher.unpin_from_dock") : I18n.t("launcher.pin_to_dock"),
                "icon": pinned ? Icons.unpin : Icons.pin,
                "variant": pinned ? "error" : "tertiary"
            },
            {
                "id": "shortcut",
                "text": I18n.t("launcher.create_shortcut"),
                "icon": Icons.shortcut,
                "variant": "secondary"
            }
        ];
    }

    function createShortcut(app) {
        const desktopDir = Quickshell.env("XDG_DESKTOP_DIR") || Quickshell.env("HOME") + "/Desktop";
        const filePath = desktopDir + "/" + app.id + "-" + Date.now() + ".desktop";
        const content = "[Desktop Entry]\nVersion=1.0\nType=Application\nName=" + app.name + "\nExec=" + app.execString + "\nIcon=" + app.icon + "\n" + (app.comment ? "Comment=" + app.comment + "\n" : "") + (app.categories && app.categories.length > 0 ? "Categories=" + app.categories.join(";") + ";\n" : "") + (app.runInTerminal ? "Terminal=true\n" : "Terminal=false\n");
        shortcutProcess.command = ["sh", "-c", "printf '%s' \"$1\" > \"$2\" && chmod 755 \"$2\" && gio set \"$2\" metadata::trusted true", "sh", content, filePath];
        shortcutProcess.running = true;
    }

    property Process shortcutProcess: Process {}

    property Connections usage: Connections {
        target: UsageTracker
        function onUsageDataReady() {
            AppSearch.invalidateCache();
            if (apps.mode !== "")
                apps.search(apps.query, apps.mode);
        }
    }
}
