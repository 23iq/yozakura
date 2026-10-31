pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.components.kit
import qs.modules.bar.sentence
import "../sentence/Sentence.js" as Sentence

// The bar read as one line: "Saturday, 18:20 — Firefox on desk 2 —
// battery 82%" (SentenceData + SentenceLine). Each fragment does what its
// module does: day and time / weather the clock panel, window and
// workspace the overview, battery the battery popup, volume the levels,
// network its settings page, the track the media panel (middle click
// plays / pauses), notifications the history (right click: do not
// disturb). A narrow bar drops the lowest ranked fragments; a vertical
// bar turns the line to read along it (bottom-up on the left edge,
// top-down on the right). moduleOptions.sentence: fragments, priority,
// separator, verbosity, typeface, maxWidth.
BarModuleBase {
    id: root

    moduleKey: "sentence"

    readonly property string screenName: root.bar && root.bar.screen ? root.bar.screen.name : ""
    readonly property bool editorial: root.options.typeface !== "body"
    readonly property real barLength: root.bar ? (root.vertical ? root.bar.height : root.bar.width) : 0
    // The island on this bar's edge: the line stops short of it
    readonly property rect notchBox: Visibilities.notchRect(root.screenName)
    readonly property real notchSpan: Config.notchPosition === root.edge ? (root.vertical ? root.notchBox.height : root.notchBox.width) : 0
    property real room: Infinity
    // Half the bar, or moduleOptions.sentence.maxWidth, short of the notch
    readonly property real budget: Sentence.budget(root.barLength, root.options.maxWidth || 0, root.room)
    readonly property real pad: root.flat ? Space.m : Space.l * 1.5

    function measureRoom(): void {
        if (!root.bar || root.notchSpan <= 0) {
            root.room = Infinity;
            return;
        }
        const p = root.mapToItem(root.bar, 0, 0);
        root.room = Sentence.room(root.vertical ? p.y : p.x, root.vertical ? root.height : root.width, root.barLength, root.notchSpan, Space.l);
    }

    onXChanged: Qt.callLater(root.measureRoom)
    onYChanged: Qt.callLater(root.measureRoom)
    onWidthChanged: Qt.callLater(root.measureRoom)
    onHeightChanged: Qt.callLater(root.measureRoom)
    onNotchSpanChanged: Qt.callLater(root.measureRoom)
    onBarLengthChanged: Qt.callLater(root.measureRoom)
    Connections {
        target: root.parent
        function onXChanged() {
            Qt.callLater(root.measureRoom);
        }
        function onYChanged() {
            Qt.callLater(root.measureRoom);
        }
    }

    visible: facts.fragments.length > 0
    contentLength: root.visible ? line.implicitWidth + root.pad : 0

    function activate(fragment: var, item: Item, button: int): void {
        if (button === Qt.MiddleButton) {
            const p = MprisController.activePlayer;
            if (fragment.id === "media" && p && p.canTogglePlaying)
                p.togglePlaying();
            return;
        }
        if (button === Qt.RightButton) {
            if (fragment.id === "notifications")
                Notifications.toggleDnd();
            return;
        }
        root.place(item);
        switch (fragment.action) {
        case "overview":
            GlobalShortcuts.run("overview");
            break;
        case "network":
            GlobalStates.settingsCategory = "network";
            if (!GlobalStates.settingsWindowVisible)
                GlobalShortcuts.toggleSettings(root.screenName);
            break;
        default:
            popups.toggle(fragment.action);
        }
    }

    // The popup anchor: the fragment's span along the bar, the module's
    // full depth across it (popups open off the bar edge, not the text)
    function place(item: Item): void {
        const r = item.mapToItem(root, 0, 0, item.width, item.height);
        anchorSpan.x = root.vertical ? 0 : r.x;
        anchorSpan.width = root.vertical ? root.width : r.width;
        anchorSpan.y = root.vertical ? r.y : 0;
        anchorSpan.height = root.vertical ? r.height : root.height;
    }

    SentenceData {
        id: facts
        order: Sentence.normalizeList(root.options.fragments, Sentence.DEFAULT_ORDER)
        verbosity: Sentence.verbosity(root.options.verbosity)
        active: !SuspendManager.isSuspending
    }

    BarModuleSurface {
        id: surface
        module: root
        active: popups.anyOpen
    }

    Item {
        id: stage
        objectName: "sentenceStage"
        anchors.centerIn: parent
        width: line.implicitWidth
        height: line.implicitHeight
        rotation: root.vertical ? (root.edge === "right" ? 90 : -90) : 0

        SentenceLine {
            id: line
            objectName: "sentenceLine"
            anchors.fill: parent
            fragments: facts.fragments
            priority: Sentence.normalizePriority(root.options.priority)
            budget: Math.max(0, root.budget - root.pad)
            separator: Sentence.separator(root.options.separator)
            textFont: root.editorial ? Type.family("editorial") : root.textFont
            textSize: root.editorial ? Math.round(root.textSize * Type.scale.editorial) : root.textSize
            textWeight: root.editorial ? Type.weight("editorial") : root.textWeight
            ink: surface.foreground
            onActivated: (fragment, item, button) => root.activate(fragment, item, button)
        }
    }

    Item {
        id: anchorSpan
    }

    SentencePopups {
        id: popups
        anchorItem: anchorSpan
        bar: root.bar
        screenName: root.screenName
        now: facts.now
        use12h: facts.use12h
    }
}
