pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.theme
import qs.modules.services
import qs.modules.specials
import qs.config
import qs.modules.settings
import qs.modules.settings.store
import qs.modules.settings.editors.specials
import "../Ui.js" as Ui
import "../../specials/Specials.js" as Specials

// Special workspaces (config specials.workspaces): quick templates, then
// one card per special. Every edit writes the whole list through
// SettingsStore; Specials.js does the pure edits. On compositors without
// special workspaces only a notice is shown.
Column {
    id: root

    property var entry
    // Onboarding shows the cards expanded and without the header text.
    property bool compact: false
    // Which cards are open, by special id. Every edit rewrites the list and
    // the Repeater rebuilds its cards, so the state lives here, not in them.
    property var open: ({})

    readonly property var items: (SettingsStore.get("specials.workspaces") || []).map(Specials.normalize)
    readonly property var names: Specials.hyprNames(items)
    readonly property var problems: {
        const out = {};
        Specials.problems(items).forEach(p => out[p.id] = I18n.t("specials.problem." + p.kind));
        return out;
    }
    readonly property bool supported: SpecialsService.supported || YozdService.compositorName === ""

    spacing: 12

    function setOpen(id, value) {
        if (!!root.open[id] === value)
            return;
        const next = Object.assign({}, root.open);
        next[id] = value;
        root.open = next;
    }

    function write(list) {
        SettingsStore.set("specials.workspaces", list);
    }

    function available(desktopId) {
        const e = DesktopEntries.byId ? DesktopEntries.byId(desktopId) : null;
        return e ? {
            "id": e.id,
            "name": e.name,
            "icon": e.icon,
            "execString": e.execString,
            "startupClass": e.startupClass || ""
        } : null;
    }

    function addFromTemplate(templateId) {
        const item = Specials.create(root.items, templateId, (k, n) => I18n.t(k, n), root.available);
        root.setOpen(item.id, true);
        root.write(root.items.concat([item]));
    }

    Rectangle {
        visible: !root.supported
        width: parent.width
        height: notice.implicitHeight + 24
        radius: Math.min(Styling.radius(2), 16)
        color: Ui.alpha(Colors.error, 0.1)
        border.width: 1
        border.color: Ui.alpha(Colors.error, 0.4)
        Text {
            id: notice
            x: 12
            y: 12
            width: parent.width - 24
            text: I18n.t("specials.unsupported", YozdService.compositorName)
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overBackground
            wrapMode: Text.WordWrap
        }
    }

    Text {
        visible: !root.compact
        width: parent.width
        text: I18n.t("specials.templates_hint")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        color: Colors.overSurfaceVariant
        wrapMode: Text.WordWrap
    }

    TemplateChips {
        width: parent.width
        onChosen: id => root.addFromTemplate(id)
    }

    Text {
        visible: root.items.length === 0
        width: parent.width
        topPadding: 6
        bottomPadding: 6
        text: I18n.t("specials.empty")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        color: Colors.overSurfaceVariant
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }

    Repeater {
        model: root.items
        delegate: SpecialCard {
            required property var modelData
            width: root.width
            item: modelData
            hyprName: root.names[modelData.id] || ""
            windows: SpecialsService.counts[root.names[modelData.id]] || 0
            problem: root.problems[modelData.id] || ""
            expanded: root.compact || !!root.open[modelData.id]
            onExpandedChanged: if (!root.compact)
                root.setOpen(modelData.id, expanded)
            onPatched: patch => root.write(Specials.withItem(root.items, modelData.id, patch))
            onAppAdded: app => root.write(Specials.withApp(root.items, modelData.id, app))
            onAppPatched: (index, patch) => root.write(Specials.withAppPatch(root.items, modelData.id, index, patch))
            onAppRemoved: index => root.write(Specials.withoutApp(root.items, modelData.id, index))
            onRemoveRequested: root.write(Specials.withoutItem(root.items, modelData.id))
        }
    }
}
