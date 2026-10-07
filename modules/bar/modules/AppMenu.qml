pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.components.kit
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
        font.family: root.vertical ? Icons.font : root.textFont
        font.pixelSize: root.vertical ? root.iconSize : root.textSize
        font.weight: root.textWeight
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
        objectName: "appMenuPopup"
        anchorItem: surface
        bar: root.bar
        popupPadding: Look.surfacePadding
        contentWidth: Math.max(260, moveTo.implicitWidth) + popupPadding * 2
        contentHeight: menu.implicitHeight + popupPadding * 2

        Column {
            id: menu
            width: parent.width
            spacing: Space.xs

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

            // Move to another workspace: one chip per workspace, the
            // window's own selected
            Group {
                id: moveTo
                width: parent.width
                label: I18n.t("bar.app_menu.move_to")
                divider: true

                Grid {
                    columns: 5
                    spacing: Space.s

                    Repeater {
                        model: root.workspaces
                        delegate: Chip {
                            required property int index
                            readonly property int ws: index + 1
                            width: Space.controlM
                            text: String(ws)
                            active: ws === root.currentWorkspace
                            enabled: root.address !== ""
                            onClicked: {
                                if (!active)
                                    root.run(`movetoworkspacesilent ${ws}, address:${root.address}`);
                            }
                        }
                    }
                }
            }

            Divider {
                width: parent.width
            }

            MenuRow {
                icon: "cancel"
                label: I18n.t("bar.app_menu.close")
                danger: true
                enabled: root.address !== ""
                onTriggered: root.run(`closewindow address:${root.address}`)
            }
        }
    }
}
