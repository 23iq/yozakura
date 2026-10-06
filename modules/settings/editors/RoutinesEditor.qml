pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.settings.editors.routines
import "../../routines/RoutineModel.js" as RoutineModel

// Routines (backend svc/routines, ~/.config/<app>/routines.json): quick
// templates, then one card per routine. Edits stay in drafts until Save;
// Test run executes the draft without saving. A routine runs from a
// keybind ("Run routine"), the launcher, an AI automation or the AI.
ColumnLayout {
    id: root

    property var entry

    // Drafts by routine id ("__new" for the unsaved new one).
    property var drafts: ({})
    property var reports: ({})
    property var errors: ({})
    property string openId: ""
    property string busyId: ""

    readonly property var saved: RoutinesService.routines || []
    // Card keys as text: the Repeater rebuilds its cards only when a routine
    // is added or removed, not on every draft edit.
    readonly property string cardKeys: JSON.stringify((drafts["__new"] ? ["__new"] : []).concat(saved.map(r => r.id)))
    readonly property var cards: JSON.parse(cardKeys)

    function savedRoutine(key) {
        return root.saved.find(r => r.id === key) || null;
    }

    spacing: 10

    function setMap(name, key, value) {
        const next = Object.assign({}, root[name]);
        if (value === undefined)
            delete next[key];
        else
            next[key] = value;
        root[name] = next;
    }

    function startNew(templateId) {
        const r = templateId ? RoutineModel.fromTemplate(templateId, k => I18n.t(k)) : RoutineModel.newRoutine(I18n.t("routines.new_name"));
        root.setMap("drafts", "__new", r);
        root.setMap("reports", "__new", undefined);
        root.openId = "__new";
    }

    function current(key, fallback) {
        return root.drafts[key] || fallback;
    }

    function save(key) {
        const r = root.drafts[key];
        if (!r)
            return;
        root.busyId = key;
        RoutinesService.save(r, key === "__new" ? "" : key, (result, error) => {
            root.busyId = "";
            root.setMap("errors", key, error || undefined);
            if (error)
                return;
            root.setMap("drafts", key, undefined);
            if (result && result.routine && root.openId === key)
                root.openId = result.routine.id;
            RoutinesService.refresh();
        });
    }

    function test(key, routine) {
        root.busyId = key;
        RoutinesService.test(routine, (result, error) => {
            root.busyId = "";
            root.setMap("errors", key, error || undefined);
            root.setMap("reports", key, result || undefined);
        });
    }

    function run(key) {
        root.busyId = key;
        RoutinesService.call("run", {
            "id": key,
            "quiet": true
        }, (result, error) => {
            root.busyId = "";
            root.setMap("errors", key, error || undefined);
            root.setMap("reports", key, result || undefined);
        });
    }

    function remove(key) {
        if (key === "__new") {
            root.setMap("drafts", "__new", undefined);
            return;
        }
        RoutinesService.remove(key, (result, error) => {
            root.setMap("errors", key, error || undefined);
            if (!error)
                RoutinesService.refresh();
        });
    }

    Component.onCompleted: RoutinesService.refresh()

    Text {
        Layout.fillWidth: true
        text: I18n.t("routines.hint")
        wrapMode: Text.WordWrap
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        color: Colors.overSurfaceVariant
    }

    Flow {
        Layout.fillWidth: true
        spacing: 6
        Chip {
            objectName: "newRoutine"
            glyph: Icons.plus
            label: I18n.t("routines.new")
            active: true
            onClicked: root.startNew("")
        }
        Repeater {
            model: RoutineModel.TEMPLATES
            delegate: Chip {
                required property var modelData
                objectName: "template:" + modelData.id
                glyph: Icons[modelData.icon]
                label: I18n.t(modelData.name)
                onClicked: root.startNew(modelData.id)
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: root.cards.length === 0
        topPadding: 8
        bottomPadding: 8
        text: I18n.t("routines.empty")
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        color: Colors.outline
    }

    Repeater {
        model: root.cards
        delegate: RoutineCard {
            id: card
            required property string modelData
            readonly property string key: modelData
            Layout.fillWidth: true
            routine: root.current(key, root.savedRoutine(key)) || RoutineModel.newRoutine("")
            isNew: key === "__new"
            dirty: root.drafts[key] !== undefined
            expanded: root.openId === key
            busy: root.busyId === key
            report: root.reports[key] || null
            error: root.errors[key] || ""
            onEdited: r => root.setMap("drafts", card.key, r)
            onToggleRequested: root.openId = root.openId === card.key ? "" : card.key
            onSaveRequested: root.save(card.key)
            onTestRequested: root.test(card.key, card.routine)
            onRunRequested: root.run(card.key)
            onDiscardRequested: root.setMap("drafts", card.key, undefined)
            onRemoveRequested: root.remove(card.key)
        }
    }
}
