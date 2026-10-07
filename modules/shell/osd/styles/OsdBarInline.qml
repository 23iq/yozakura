import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.shell.osd
import qs.modules.components.kit
import "../OsdStyles.js" as OsdStyles

// Lives inside the bar's controls button: on an OSD event the button grows
// by `reveal` (the host adds it to its length along the bar) and turns into
// the level icon and a kit LineSlider with the value, then settles back.
// The slider is live (drag / wheel set the level) and hovering keeps it up.
// Registers with OsdService so the window falls back to the pill when no
// bar widget exists.
Item {
    id: root

    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property string device: ""
    property bool vertical: false
    property bool shown: false
    property real radius: 0
    property var screen: null
    // Set by the bar host, independently of this item's shown/visible state.
    property bool available: true
    property bool _mounted: false
    property bool _registered: false
    property string _registeredScreen: ""

    function syncRegistration(): void {
        if (!root._mounted)
            return;
        if (root._registered)
            OsdService.registerInline(false, root._registeredScreen);
        root._registered = root.available;
        root._registeredScreen = root.screen ? root.screen.name : "";
        if (root._registered)
            OsdService.registerInline(true, root._registeredScreen);
        else
            root.shown = false;
    }

    function accepts(kind: string): bool {
        return root.available && !(kind === "brightness" && OsdService.lastScreen && root.screen && OsdService.lastScreen !== root.screen.name && !Brightness.syncBrightness);
    }

    onAvailableChanged: syncRegistration()
    onScreenChanged: syncRegistration()
    // Extra length the host grows by while shown (animated).
    readonly property int length: Math.round(Metrics.osdW * 0.7)
    property real reveal: root.shown ? root.length : 0
    readonly property var readout: OsdStyles.readout(root.kind, root.value, root.muted, root.device, "", I18n.t("osd.muted"))

    visible: opacity > 0
    opacity: root.shown ? 1 : 0
    enabled: root.shown
    z: 1

    Behavior on reveal {
        enabled: OsdMotion.enterMs > 0
        NumberAnimation {
            duration: root.shown ? OsdMotion.enterMs : OsdMotion.exitMs
            easing.type: root.shown ? OsdMotion.enterEasing : OsdMotion.exitEasing
        }
    }
    Behavior on opacity {
        enabled: OsdMotion.enterMs > 0
        NumberAnimation {
            duration: root.shown ? OsdMotion.enterMs : OsdMotion.exitMs
            easing.type: root.shown ? OsdMotion.enterEasing : OsdMotion.exitEasing
        }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: hovered ? settle.stop() : settle.restart()
    }

    GridLayout {
        anchors.fill: parent
        anchors.leftMargin: root.vertical ? 0 : Space.m
        anchors.rightMargin: root.vertical ? 0 : Space.m
        anchors.topMargin: root.vertical ? Space.m : 0
        anchors.bottomMargin: root.vertical ? Space.m : 0
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: Space.s
        columnSpacing: Space.s

        OsdGlyph {
            Layout.alignment: Qt.AlignCenter
            Layout.row: root.vertical ? 1 : 0
            Layout.column: 0
            kind: root.kind
            value: root.value
            muted: root.muted
        }

        LineSlider {
            id: slider
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.row: 0
            Layout.column: root.vertical ? 0 : 1
            implicitWidth: root.vertical ? Space.controlS : 0
            implicitHeight: root.vertical ? 0 : Space.controlS
            vertical: root.vertical
            step: Math.abs(OsdStyles.wheelStep(1))
            showValue: true
            valueText: root.readout.value !== "" ? root.readout.value : root.readout.title
            highlighted: hover.hovered
            // Muted: the level stays, quieted.
            opacity: root.readout.level ? 1 : 0.5
            onMoved: v => {
                OsdService.adjust(root.kind, v - root.value, root.screen);
                settle.restart();
            }
        }
    }

    // Follows the level even after the slider set its own value on a drag.
    Binding {
        target: slider
        property: "value"
        value: root.value
    }

    Timer {
        id: settle
        interval: OsdService.timeout
        onTriggered: root.shown = false
    }

    Connections {
        target: OsdService

        function onInlineRequest(kind) {
            if (!root.accepts(kind))
                return;
            root.kind = kind;
            root.value = OsdService.lastValue;
            root.muted = OsdService.lastMuted;
            root.shown = true;
            if (!hover.hovered)
                settle.restart();
        }

        function onLevel(kind, value, muted, device) {
            // Follow the level of what is showing; a different kind arrives
            // as its own inlineRequest, which also restarts the settle timer.
            if (root.shown && kind === root.kind && root.accepts(kind)) {
                root.value = value;
                root.muted = muted;
            }
        }
    }

    Component.onCompleted: {
        root._mounted = true;
        root.syncRegistration();
    }
    Component.onDestruction: {
        if (root._registered)
            OsdService.registerInline(false, root._registeredScreen);
    }
}
