pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import "DockMagnify.js" as DockMagnify
import "AppNames.js" as AppNames

// One app of the Taskbar module: icon, running indicators, launch bounce.
// `dock` sizes it for dock panels (big icon, dots); otherwise it is a
// taskbar button (icon + underline pill for running / focused).
Item {
    id: btn

    required property var app
    property bool dock: false
    property bool vertical: false
    property string edge: "bottom"
    property real cell: 36
    property real magnify: 1
    property bool bounceOnLaunch: false
    property bool showLabel: false

    readonly property bool separator: app && app.appId === "SEPARATOR"
    readonly property var entry: separator || !app ? null : DesktopEntries.heuristicLookup(app.appId)
    readonly property int windows: separator || !app ? 0 : (app.toplevelCount !== undefined ? app.toplevelCount : (app.toplevels ? app.toplevels.length : 0))
    readonly property bool running: windows > 0
    readonly property bool focused: running && app.toplevels.some(t => t && t.activated === true)
    readonly property string name: entry && entry.name ? entry.name : AppNames.pretty(app ? app.appId : "")
    readonly property string iconName: entry && entry.icon ? entry.icon : AppSearch.guessIcon(app ? app.appId : "")
    readonly property real iconSize: Math.round(cell * (dock ? 0.84 : 0.62) * magnify)
    property int lastFocused: -1

    implicitWidth: separator ? (vertical ? cell : Math.round(cell * 0.32)) : (vertical ? cell : Math.round(cell * magnify) + (showLabel ? label.implicitWidth + 10 : 0))
    implicitHeight: separator ? (vertical ? Math.round(cell * 0.32) : cell) : (vertical ? Math.round(cell * magnify) : cell)

    // Hover / pressed backdrop (taskbar) — docks only magnify
    StyledRect {
        visible: !btn.dock && !btn.separator && (mouse.containsMouse || btn.focused)
        anchors.fill: parent
        anchors.margins: 2
        variant: "focus"
        enableShadow: false
        radius: Styling.radius(-4)
        opacity: btn.focused ? 0.75 : 0.55
    }

    Rectangle {
        visible: btn.separator
        anchors.centerIn: parent
        width: btn.vertical ? btn.cell * 0.55 : 1
        height: btn.vertical ? 1 : btn.cell * 0.55
        color: Colors.outlineVariant
    }

    Item {
        id: iconBox
        visible: !btn.separator
        width: btn.iconSize
        height: btn.iconSize
        // Docks grow out of the panel, away from the screen edge
        x: btn.vertical ? (btn.edge === "right" ? btn.width - width - (btn.dock ? btn.cell * 0.08 : (btn.cell - width) / 2) : (btn.dock ? btn.cell * 0.08 : (btn.cell - width) / 2)) : (btn.showLabel ? 6 : (btn.width - width) / 2)
        y: btn.vertical ? (btn.height - height) / 2 : (btn.edge === "top" ? (btn.dock ? btn.cell * 0.08 : (btn.cell - height) / 2) : btn.height - height - (btn.dock ? btn.cell * 0.08 : (btn.cell - height) / 2)) - bounce.offset

        Image {
            anchors.fill: parent
            source: btn.separator || !btn.app ? "" : "image://icon/" + btn.iconName
            sourceSize: Qt.size(Math.round(btn.cell * 1.8), Math.round(btn.cell * 1.8))
            fillMode: Image.PreserveAspectFit
            mipmap: true
            smooth: true
        }

        QtObject {
            id: bounce
            property real offset: 0
        }

        SequentialAnimation {
            id: bounceAnim
            loops: 3
            NumberAnimation {
                target: bounce
                property: "offset"
                to: btn.cell * 0.32
                duration: 220
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: bounce
                property: "offset"
                to: 0
                duration: 260
                easing.type: Easing.OutBounce
            }
        }
    }

    Text {
        id: label
        visible: btn.showLabel && !btn.separator && !btn.vertical
        anchors.verticalCenter: parent.verticalCenter
        x: iconBox.x + iconBox.width + 8
        text: btn.name
        elide: Text.ElideRight
        width: Math.min(implicitWidth, 140)
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        color: Colors.overBackground
    }

    // Running indicators: dots (dock) or an underline pill (taskbar)
    Row {
        visible: btn.running && !btn.vertical
        anchors.horizontalCenter: iconBox.horizontalCenter
        y: btn.edge === "top" ? 1 : btn.height - height - (btn.dock ? 1 : 2)
        spacing: 3
        Repeater {
            model: btn.dock ? DockMagnify.dotCount(btn.windows) : 1
            delegate: Rectangle {
                width: btn.dock ? 5 : (btn.focused ? btn.cell * 0.42 : btn.cell * 0.18)
                height: btn.dock ? 5 : 3
                radius: height / 2
                color: btn.focused ? Colors.primary : Colors.overSurfaceVariant
                opacity: btn.focused ? 1 : 0.7
                Behavior on width {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Motion.exit.duration
                        easing.type: Motion.morph.easing
                    }
                }
            }
        }
    }
    Column {
        visible: btn.running && btn.vertical
        anchors.verticalCenter: iconBox.verticalCenter
        x: btn.edge === "right" ? 1 : btn.width - width - 1
        spacing: 3
        Repeater {
            model: btn.dock ? DockMagnify.dotCount(btn.windows) : 1
            delegate: Rectangle {
                width: btn.dock ? 5 : 3
                height: btn.dock ? 5 : (btn.focused ? btn.cell * 0.42 : btn.cell * 0.18)
                radius: width / 2
                color: btn.focused ? Colors.primary : Colors.overSurfaceVariant
            }
        }
    }

    StyledToolTip {
        show: mouse.containsMouse && !btn.separator
        tooltipText: btn.name
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: !btn.separator
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                TaskbarApps.togglePin(btn.app.appId);
                return;
            }
            if (mouse.button === Qt.MiddleButton || !btn.running) {
                TaskbarApps.launchApp(btn.app.appId);
                if (btn.bounceOnLaunch && !btn.running)
                    bounceAnim.restart();
                return;
            }
            btn.lastFocused = (btn.lastFocused + 1) % btn.windows;
            btn.app.toplevels[btn.lastFocused].activate();
        }
    }

    onRunningChanged: if (running)
        bounceAnim.stop()
}
