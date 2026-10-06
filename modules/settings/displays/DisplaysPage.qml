import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import "../../services/DisplayModel.js" as DisplayModel
import "DisplayFormat.js" as DisplayFormat

// Settings > Displays: arrange the monitors on a canvas, tune the selected
// one, apply live. The layout runs for 15 s on every screen with a "keep
// these settings?" prompt (DisplayConfirmOverlay); keeping it saves it.
Flickable {
    id: page

    required property var category

    // The layout being edited: one config per connected output
    property var draft: []
    property string selectedName: ""
    property string error: ""

    readonly property var live: DisplaysService.currentConfigs()
    readonly property bool dirty: JSON.stringify(draft) !== JSON.stringify(live)
    readonly property var selectedConfig: draft.find(c => c.name === selectedName) ?? null
    readonly property int selectedIndex: draft.findIndex(c => c.name === selectedName)

    contentWidth: width
    contentHeight: column.implicitHeight + 120
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
    }

    // SettingsShell calls reveal() on search jumps for every page type; this
    // page is a single block with no entries to scroll to, so it is a no-op.
    function reveal(section, entry) {
    }

    function resync() {
        draft = DisplaysService.currentConfigs();
        if (!draft.some(c => c.name === selectedName))
            selectedName = draft.length > 0 ? draft[0].name : "";
    }

    function enabledCount(list) {
        return list.filter(c => c.enabled !== false).length;
    }

    // Applies `values` to one monitor of the draft, then re-arranges so size,
    // rotation or enabling it never leaves tiles overlapping.
    function edit(name, values) {
        const cur = draft.find(c => c.name === name);
        if (!cur)
            return;
        if (values.enabled === false && enabledCount(draft) <= 1 && cur.enabled !== false)
            return;
        const next = Object.assign({}, cur, values);
        if (values.enabled === true && cur.enabled === false) {
            next.x = draft.reduce((m, c) => c.enabled === false ? m : Math.max(m, c.x + DisplayModel.logicalSize(c).w), 0);
            next.y = 0;
        }
        const list = draft.map(c => c.name === name ? next : c);
        draft = values.enabled === false ? list : DisplayModel.arrange(list, name, next.x, next.y);
    }

    function pickResolution(name, width, height) {
        const out = DisplayFormat.outputFor(DisplaysService.outputs, name);
        const mode = Object.assign({}, out, {
            "width": width,
            "height": height
        });
        edit(name, {
            "width": width,
            "height": height,
            "refresh": out ? DisplayModel.bestRefresh(mode) : 0
        });
    }

    function applyDraft() {
        error = "";
        DisplaysService.apply(draft);
    }

    Component.onCompleted: {
        DisplaysService.refresh();
        DisplaysService.scanConflicts();
        resync();
    }

    Connections {
        target: DisplaysService
        function onOutputsChanged() {
            const names = DisplaysService.outputs.map(o => o.name).join();
            if (!page.dirty || names !== page.draft.map(c => c.name).join())
                page.resync();
        }
        function onApplyFailed(message) {
            page.error = message;
        }
    }

    Column {
        id: column
        width: Math.min(page.width - 64, 820)
        x: (page.width - width) / 2
        y: 36
        spacing: 22

        PageHeader {
            width: parent.width
            category: page.category
        }

        DisplayNotice {
            objectName: "applyError"
            width: parent.width
            visible: page.error !== ""
            tone: "error"
            icon: "warning"
            title: I18n.t("prefs.displays.apply_failed")
            message: page.error
        }

        DisplayPendingNote {
            objectName: "deferredNote"
            width: parent.width
            visible: DisplaysService.pending && !DisplaysService.session.live
        }

        DisplayConflictBanner {
            objectName: "conflictBanner"
            width: parent.width
            visible: DisplaysService.conflicts.length > 0
            count: DisplaysService.conflicts.length
            onMoveRequested: DisplaysService.moveConflicts()
        }

        DisplayArrangement {
            objectName: "arrangement"
            width: parent.width
            configs: page.draft
            outputs: DisplaysService.outputs
            selectedName: page.selectedName
            onPicked: name => page.selectedName = name
            onMoved: (name, x, y) => page.draft = DisplayModel.arrange(page.draft, name, x, y)
        }

        DisplayDetails {
            objectName: "details"
            width: parent.width
            visible: page.selectedConfig !== null
            config: page.selectedConfig
            output: page.selectedConfig ? DisplayFormat.outputFor(DisplaysService.outputs, page.selectedName) : null
            dirty: page.dirty
            busy: DisplaysService.pending
            onPatch: values => page.edit(page.selectedName, values)
            onResolutionPicked: (w, h) => page.pickResolution(page.selectedName, w, h)
            onIdentify: DisplaysService.identify()
            onDiscard: page.resync()
            onApply: page.applyDraft()
        }
    }
}
