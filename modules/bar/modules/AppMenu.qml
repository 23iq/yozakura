pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.components

// Menubar "Window" menu for the focused window: close, fullscreen, float,
// pin, center and move to another workspace.
BarModuleBase {
    id: root

    moduleKey: "appMenu"

    readonly property var client: YozdService.focusedClient
    readonly property string address: client && client.address ? client.address : ""
    readonly property int workspaces: Config.workspaces && Config.workspaces.shown ? Config.workspaces.shown : 10
    readonly property int currentWorkspace: client && client.workspace ? client.workspace.id : 0

    contentLength: vertical ? moduleSize : label.implicitWidth + (flat ? 16 : 28)

    function run(cmd) {
        YozdService.dispatch(cmd);
        popup.close();
    }

    BarModuleSurface {
        id: surface
        module: root
        active: popup.isOpen
        hovered: mouse.containsMouse
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.vertical ? (Icons.list ?? "") : I18n.t("bar.app_menu.window")
        font.family: root.vertical ? Icons.font : Config.theme.font
        font.pixelSize: root.vertical ? root.iconSize : root.textSize
        font.weight: Font.Medium
        color: surface.foreground
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.toggle()
    }

    BarPopup {
        id: popup
        anchorItem: surface
        bar: root.bar
        contentWidth: menu.implicitWidth + popupPadding * 2
        contentHeight: menu.implicitHeight + popupPadding * 2

        ColumnLayout {
            id: menu
            anchors.centerIn: parent
            spacing: 2
            width: Math.max(implicitWidth, 240)

            MenuRow {
                icon: "arrowsOut"
                label: I18n.t("bar.app_menu.fullscreen")
                enabled: root.address !== ""
                onTriggered: root.run("fullscreen 0")
            }
            MenuRow {
                icon: "popOpen"
                label: I18n.t("bar.app_menu.float")
                enabled: root.address !== ""
                onTriggered: root.run("togglefloating")
            }
            MenuRow {
                icon: "pin"
                label: I18n.t("bar.app_menu.pin")
                enabled: root.address !== ""
                onTriggered: root.run("pin")
            }
            MenuRow {
                icon: "alignCenter"
                label: I18n.t("bar.app_menu.center")
                enabled: root.address !== ""
                onTriggered: root.run("centerwindow")
            }

            Text {
                Layout.topMargin: 8
                Layout.leftMargin: 12
                text: I18n.t("bar.app_menu.move_to")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.Bold
                color: Colors.overSurfaceVariant
            }

            GridLayout {
                Layout.margins: 6
                columns: 5
                rowSpacing: 4
                columnSpacing: 4

                Repeater {
                    model: root.workspaces
                    delegate: StyledRect {
                        id: chip
                        required property int index
                        readonly property int ws: index + 1
                        readonly property bool current: ws === root.currentWorkspace
                        variant: current ? "primary" : (chipMouse.containsMouse ? "focus" : "common")
                        enableShadow: false
                        radius: Styling.radius(-4)
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 30

                        Text {
                            anchors.centerIn: parent
                            text: chip.ws
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Bold
                            color: chip.item
                        }
                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.address !== "" && !chip.current
                            onClicked: root.run(`movetoworkspacesilent ${chip.ws}, address:${root.address}`)
                        }
                    }
                }
            }

            MenuRow {
                Layout.topMargin: 4
                icon: "cancel"
                label: I18n.t("bar.app_menu.close")
                danger: true
                enabled: root.address !== ""
                onTriggered: root.run(`closewindow address:${root.address}`)
            }
        }
    }
}
