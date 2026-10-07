pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.bar.look
import qs.modules.theme
import qs.modules.shell.osd.styles

// Bar "controls" module: a faders glyph; left click opens the levels popup
// (volume, microphone, brightness as kit LineSliders, the glyph toggles
// mute), right click opens pavucontrol.
Item {
    id: root

    required property var bar

    property bool vertical: bar.orientation === "vertical"
    property bool isHovered: false
    property bool layerEnabled: true

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius
    // Bar panels: module size, and "flat" (no group box of its own)
    property int moduleSize: BarMetrics.moduleSize
    property bool flat: false

    // Popup visibility state (tracks intent, not animation)
    property bool popupOpen: controlsPopup.isOpen
    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(root.bar.screen)

    objectName: "controlsModule"
    // The OSD bar-inline style grows the button into a level slider.
    Layout.preferredWidth: root.moduleSize + (root.vertical ? 0 : inlineOsd.reveal)
    Layout.preferredHeight: root.moduleSize + (root.vertical ? inlineOsd.reveal : 0)
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical

    function volumeIcon(audio: var): string {
        if (audio?.muted)
            return Icons.speakerSlash;
        const vol = audio?.volume ?? 0;
        if (vol < 0.01)
            return Icons.speakerX;
        if (vol < 0.19)
            return Icons.speakerNone;
        if (vol < 0.49)
            return Icons.speakerLow;
        return Icons.speakerHigh;
    }

    function setBrightness(v: real) {
        if (Brightness.syncBrightness) {
            for (let i = 0; i < Brightness.monitors.length; i++) {
                const mon = Brightness.monitors[i];
                if (mon && mon.ready)
                    mon.setBrightness(v);
            }
        } else if (root.brightnessMonitor && root.brightnessMonitor.ready) {
            root.brightnessMonitor.setBrightness(v);
        }
    }

    StyledToolTip {
        show: root.isHovered && !root.popupOpen
        tooltipText: I18n.t("bar.tooltip.controls")
    }

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    Item {
        id: buttonBg
        anchors.fill: parent

        ModuleBox {
            id: box
            vertical: root.vertical
            startRadius: root.startRadius
            endRadius: root.endRadius
            flat: root.flat
            shadow: root.layerEnabled
            active: root.popupOpen
            hovered: root.isHovered
        }

        Text {
            anchors.centerIn: parent
            text: Icons.faders
            font.family: Icons.font
            font.pixelSize: BarLook.iconSize(root.moduleSize)
            color: box.ink
            opacity: 1 - inlineOsd.opacity
        }

        OsdBarInline {
            id: inlineOsd
            anchors.fill: parent
            radius: Math.max(root.startRadius, root.endRadius)
            vertical: root.vertical
            screen: root.bar ? root.bar.screen : null
            available: root.visible && !!root.bar && root.bar.reveal
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    Quickshell.execDetached(["pavucontrol"]);
                else
                    controlsPopup.toggle();
            }
        }
    }

    // A click on the OSD opens the controls popup of its screen.
    Connections {
        target: OsdService

        function onControlsRequested(screenName) {
            const mine = root.bar && root.bar.screen ? root.bar.screen.name : "";
            if (screenName === "" || mine === "" || screenName === mine)
                controlsPopup.open();
        }
    }

    BarPopup {
        id: controlsPopup
        objectName: "controlsPopup"
        anchorItem: buttonBg
        bar: root.bar
        popupPadding: Look.surfacePadding

        contentWidth: 280 + popupPadding * 2
        contentHeight: levels.implicitHeight + popupPadding * 2

        // The levels as one kit group (a frosted card in glass, a tile in tiles)
        Group {
            id: levels
            width: parent.width

            LevelRow {
                id: volumeRow
                icon: root.volumeIcon(Audio.sink?.audio)
                muted: Audio.sink?.audio?.muted ?? false
                value: Audio.sink?.audio?.volume ?? 0
                onMoved: v => {
                    if (Audio.sink?.audio)
                        Audio.sink.audio.volume = v;
                }
                onIconClicked: {
                    if (Audio.sink?.audio)
                        Audio.sink.audio.muted = !Audio.sink.audio.muted;
                }

                Connections {
                    target: Audio.sink?.audio ?? null
                    ignoreUnknownSignals: true
                    function onVolumeChanged() {
                        volumeRow.value = Audio.sink.audio.volume;
                    }
                }
            }

            LevelRow {
                id: micRow
                icon: Audio.source?.audio?.muted ? Icons.micSlash : Icons.mic
                muted: Audio.source?.audio?.muted ?? false
                value: Audio.source?.audio?.volume ?? 0
                onMoved: v => {
                    if (Audio.source?.audio)
                        Audio.source.audio.volume = v;
                }
                onIconClicked: {
                    if (Audio.source?.audio)
                        Audio.source.audio.muted = !Audio.source.audio.muted;
                }

                Connections {
                    target: Audio.source?.audio ?? null
                    ignoreUnknownSignals: true
                    function onVolumeChanged() {
                        micRow.value = Audio.source.audio.volume;
                    }
                }
            }

            LevelRow {
                id: brightnessRow
                icon: Icons.sun
                value: root.brightnessMonitor?.brightness ?? 0.5
                onMoved: v => root.setBrightness(v)

                Connections {
                    target: root.brightnessMonitor ?? null
                    ignoreUnknownSignals: true
                    function onBrightnessChanged() {
                        brightnessRow.value = root.brightnessMonitor.brightness;
                    }
                    function onReadyChanged() {
                        if (root.brightnessMonitor?.ready)
                            brightnessRow.value = root.brightnessMonitor.brightness;
                    }
                }
            }
        }
    }

    // One level: the glyph (a quiet button: mute toggle) + a line slider.
    component LevelRow: RowLayout {
        id: row

        property string icon: ""
        property bool muted: false
        property alias value: slider.value
        signal moved(real value)
        signal iconClicked

        width: parent ? parent.width : 0
        spacing: Space.s

        IconButton {
            size: "s"
            icon: row.icon
            onClicked: row.iconClicked()
        }

        LineSlider {
            id: slider
            Layout.fillWidth: true
            showValue: true
            opacity: row.muted ? 0.5 : 1
            onMoved: v => row.moved(v)
        }
    }
}
