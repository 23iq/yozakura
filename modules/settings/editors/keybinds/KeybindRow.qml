pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.keybinds
import qs.modules.settings.controls
import qs.config
import "../../Ui.js" as Ui

// One bind in the editor: enable switch, keycaps, what it does, conflict
// marker, reset (core binds changed from default) and a chevron; the
// details (recorder, action, description) expand below.
Item {
    id: root

    required property var bind
    readonly property bool expanded: KeybindsStore.expandedUid === bind.uid
    readonly property var conflicts: KeybindsStore.conflictsOf(bind.uid)
    readonly property bool conflicted: conflicts.length > 0
    readonly property bool modified: KeybindsStore.isModified(bind)

    objectName: "keybindRow:" + bind.uid
    implicitHeight: col.implicitHeight
    clip: true

    Behavior on implicitHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Styling.radius(-4)
        color: root.conflicted ? Ui.alpha(Colors.error, 0.08) : Ui.alpha(Colors.overBackground, root.expanded ? 0.05 : (headerArea.containsMouse ? 0.04 : 0))
        border.width: root.expanded || root.conflicted ? 1 : 0
        border.color: root.conflicted ? Ui.alpha(Colors.error, 0.5) : Ui.alpha(Colors.outlineVariant, 0.6)
    }

    Column {
        id: col
        width: parent.width

        Item {
            id: header
            width: parent.width
            height: Math.max(52, headerRow.implicitHeight + 16)

            MouseArea {
                id: headerArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: KeybindsStore.expandedUid = root.expanded ? "" : root.bind.uid
            }

            RowLayout {
                id: headerRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 12

                ToggleControl {
                    objectName: "keybindEnabled"
                    checked: root.bind.enabled
                    onToggled: v => KeybindsStore.setEnabled(root.bind.uid, v)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    opacity: root.bind.enabled ? 1 : 0.5

                    Text {
                        Layout.fillWidth: true
                        text: KeybindsStore.title(root.bind)
                        elide: Text.ElideRight
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.DemiBold
                        color: Colors.overBackground
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: root.conflicted ? KeybindsStore.conflictText(root.bind.uid).split("\n").join(" · ") : KeybindsStore.subtitle(root.bind)
                        elide: Text.ElideRight
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-3)
                        color: root.conflicted ? Colors.error : Colors.overSurfaceVariant
                    }
                }

                Column {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4
                    opacity: root.bind.enabled ? 1 : 0.5

                    Repeater {
                        model: root.bind.keys
                        delegate: KeyCombo {
                            required property var modelData
                            x: parent ? parent.width - width : 0
                            modifiers: modelData.modifiers
                            key: modelData.key
                            tone: root.conflicted ? "error" : "normal"
                            placeholder: I18n.t("binds.not_set")
                        }
                    }
                }

                Text {
                    visible: root.conflicted
                    text: Icons.warning
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(1)
                    color: Colors.error
                }

                Item {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    visible: root.modified

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: resetArea.containsMouse ? Ui.alpha(Colors.primary, 0.16) : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: Icons.arrowCounterClockwise
                        font.family: Icons.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.primary
                    }
                    MouseArea {
                        id: resetArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: KeybindsStore.reset(root.bind.uid)
                    }
                    StyledToolTip {
                        show: resetArea.containsMouse
                        tooltipText: I18n.t("common.reset_default")
                    }
                }

                Text {
                    text: Icons.caretDown
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overSurfaceVariant
                    rotation: root.expanded ? 180 : 0
                    Behavior on rotation {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        Loader {
            width: parent.width
            active: root.expanded
            visible: active
            sourceComponent: KeybindDetails {
                bind: root.bind
            }
        }
    }
}
