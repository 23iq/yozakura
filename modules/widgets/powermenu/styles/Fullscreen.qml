pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.widgets.powermenu

// layout.powermenu.style "fullscreen": large labelled tiles centered in the
// work area over a dimmed screen. Destructive tiles are held to confirm;
// Escape or a click on the backdrop closes.
FocusScope {
    id: root

    property point cursor
    property var area: null
    property bool shown: false

    signal closeRequested

    property real progress: shown ? 1 : 0
    Behavior on progress {
        enabled: Motion.enter.duration > 0
        NumberAnimation {
            duration: root.shown ? Motion.enter.duration : Motion.exit.duration
            easing.type: root.shown ? Motion.enter.easing : Motion.exit.easing
        }
    }

    function move(delta) {
        for (let i = 0; i < tiles.count; i++) {
            if (tiles.itemAt(i).activeFocus) {
                tiles.itemAt((i + delta + tiles.count) % tiles.count).forceActiveFocus();
                return;
            }
        }
        if (tiles.count > 0)
            tiles.itemAt(0).forceActiveFocus();
    }

    onActiveFocusChanged: {
        if (activeFocus)
            Qt.callLater(() => root.move(0));
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab)
            root.move(1);
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab)
            root.move(-1);
        else if (event.key === Qt.Key_Escape)
            root.closeRequested();
        else
            return;
        event.accepted = true;
    }

    PowerMenuModel {
        id: power
        onDone: root.closeRequested()
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.scrim
        opacity: 0.6 * root.progress

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    Column {
        readonly property var box: root.area || {
            "x": 0,
            "y": 0,
            "w": root.width,
            "h": root.height
        }
        x: box.x + (box.w - width) / 2
        y: box.y + (box.h - height) / 2
        spacing: Metrics.padding * 2
        opacity: root.progress
        scale: 0.92 + 0.08 * root.progress

        Row {
            spacing: Metrics.padding * 2
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                id: tiles
                model: power.items

                delegate: PowerTile {
                    required property var modelData
                    required property int index
                    action: modelData
                    size: Metrics.rowHeight * 2
                    showLabel: true
                    onActivated: power.run(index)
                    onHovered: forceActiveFocus()
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("powermenu.hold_hint")
            color: Colors.overBackground
            opacity: 0.7
            font.family: Config.defaultFont
            font.pixelSize: Styling.fontSize(-1)
        }
    }
}
