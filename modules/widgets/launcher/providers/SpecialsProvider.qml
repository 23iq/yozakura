import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.specials
import "../../../specials/Specials.js" as Specials

// Special workspaces by name ("tele" -> Telegram): Enter opens it (its
// apps are launched first, see SpecialsService). Nothing on compositors
// without special workspaces.
LauncherProvider {
    id: specials

    mixedLimit: 3

    function compute(text, searchMode) {
        if (!SpecialsService.active)
            return [];
        return Specials.search(SpecialsService.items, text).map(it => ({
                    "key": it.id,
                    "title": it.name,
                    "subtitle": I18n.t(SpecialsService.isOpen(it) ? "specials.launcher.open" : "specials.launcher.closed", SpecialsService.countOf(it)),
                    "icon": Icons[it.icon] || Icons.stack,
                    "badge": I18n.t("launcher.provider.specials"),
                    "hint": I18n.t("specials.launcher.hint"),
                    "data": {
                        "id": it.id
                    }
                }));
    }

    function activate(item, option) {
        const id = item && item.data ? item.data.id : "";
        if (!id)
            return false;
        // Toggle after the launcher closed (focus goes back first).
        Qt.callLater(() => SpecialsService.toggle(id));
        return true;
    }
}
