pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.keybinds

// One bind in the cheatsheet: its combos as keycaps, what it does, a
// conflict marker and an "edit in settings" button on hover/focus.
Item {
    id: root

    required property var bind
    property bool selected: false
    readonly property bool conflicted: (bind.uids || [bind.uid]).some(u => KeybindsStore.conflictsOf(u).length > 0)
    readonly property bool hovered: area.containsMouse || editArea.containsMouse

    signal editRequested(string uid)

    implicitHeight: Math.max(combos.implicitHeight, label.implicitHeight) + Math.round(Styling.fontSize(-2) * 0.9)
    opacity: bind.enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: Styling.radius(-6)
        color: Colors.overBackground
        opacity: root.selected ? 0.1 : (root.hovered ? 0.06 : 0)
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onDoubleClicked: root.editRequested(root.bind.uid)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 6
        spacing: 10

        Text {
            id: label
            Layout.fillWidth: true
            text: KeybindsStore.title(root.bind)
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overBackground
        }

        Text {
            visible: root.conflicted
            text: Icons.warning
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.error
        }

        Item {
            Layout.preferredWidth: editIcon.implicitWidth + 8
            Layout.preferredHeight: editIcon.implicitHeight + 8
            opacity: root.hovered || root.selected ? 1 : 0
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }

            Text {
                id: editIcon
                anchors.centerIn: parent
                text: Icons.pencil
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(-1)
                color: editArea.containsMouse ? Colors.primary : Colors.overSurfaceVariant
            }
            MouseArea {
                id: editArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.editRequested(root.bind.uid)
            }
            StyledToolTip {
                show: editArea.containsMouse
                tooltipText: I18n.t("binds.edit_in_settings")
            }
        }

        // Several combos (merged rows) stack, right-aligned.
        Column {
            id: combos
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            spacing: 4

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
    }
}
