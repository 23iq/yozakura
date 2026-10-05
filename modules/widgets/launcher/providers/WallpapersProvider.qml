import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.globals

// Wallpapers by file name after the wallpapers prefix ("ww sakura"), with
// thumbnails. Enter sets the wallpaper on every screen.
LauncherProvider {
    id: walls

    mixedLimit: 0
    readonly property int maxRows: 60
    readonly property var manager: GlobalStates.wallpaperManager

    function compute(text, searchMode) {
        const m = walls.manager;
        if (!m)
            return [];
        const q = (text || "").trim().toLowerCase();
        const paths = m.wallpaperPaths || [];
        const out = [];
        if (q === "" && paths.length > 1)
            out.push(walls.randomRow(paths.length));
        for (let i = 0; i < paths.length && out.length < walls.maxRows; i++) {
            const p = paths[i];
            const name = p.substring(p.lastIndexOf("/") + 1);
            if (q !== "" && name.toLowerCase().indexOf(q) === -1)
                continue;
            const current = p === m.currentWallpaper;
            out.push({
                "key": p,
                "title": name.replace(/\.[^.]+$/, ""),
                "subtitle": current ? I18n.t("launcher.wall.current") : p.substring(0, p.lastIndexOf("/")).replace(Brand.home, "~"),
                "image": "file://" + m.getDisplaySource(p),
                "thumb": true,
                "badge": m.getFileType ? m.getFileType(p) : "",
                "hint": I18n.t("launcher.wall.set"),
                "data": {
                    "path": p
                }
            });
        }
        if (out.length === 0 && searchMode === "prefix")
            out.push({
                "key": "none",
                "title": I18n.t("launcher.no_results"),
                "icon": Icons.image,
                "inert": true
            });
        return out;
    }

    function randomRow(count) {
        return {
            "key": "random",
            "title": I18n.t("launcher.wall.random"),
            "subtitle": I18n.t("launcher.wall.random.desc").replace("%1", count),
            "icon": Icons.shuffle,
            "hint": I18n.t("launcher.wall.set"),
            "data": {
                "random": true
            }
        };
    }

    function activate(item, option) {
        if (item.inert || !item.data || !walls.manager)
            return false;
        if (item.data.random) {
            GlobalShortcuts.run("wallpaper-random");
            return true;
        }
        walls.manager.setWallpaper(item.data.path);
        return true;
    }
}
