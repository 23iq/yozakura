import QtQuick
import qs.modules.theme
import qs.modules.services
import "../../../routines/RoutineModel.js" as RoutineModel

// Saved routines by name or keyword ("morning"): Enter runs it (the
// backend notifies when a step fails). First in mixed results; the "@"
// prefix searches only routines and lists them all when the query is empty.
// Nothing when no routine exists.
LauncherProvider {
    id: routines

    mixedLimit: 3

    function compute(text, searchMode) {
        const prefixed = searchMode === "prefix";
        if (String(text || "").trim() === "" && !prefixed)
            return [];
        return RoutineModel.search(RoutinesService.routines, text, prefixed ? 50 : 8).map(r => ({
                    "key": r.id,
                    "title": r.name,
                    "subtitle": I18n.t("routines.launcher.steps", (r.steps || []).length),
                    "icon": Icons[r.icon] || Icons.lightning,
                    "badge": I18n.t("launcher.provider.routines"),
                    "hint": I18n.t("routines.launcher.hint"),
                    "data": {
                        "id": r.id
                    }
                }));
    }

    function activate(item, option) {
        const id = item && item.data ? item.data.id : "";
        if (!id)
            return false;
        Qt.callLater(() => RoutinesService.run(id));
        return true;
    }
}
