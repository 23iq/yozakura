pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.aicenter.common
import qs.modules.components.kit

// Board without tasks: what tasks are, the keyboard, template chips.
Item {
    id: root
    objectName: "boardEmpty"

    property var templates: []
    signal templateChosen(string command)

    CenteredScroll {
        anchors.fill: parent
        maxContentWidth: 520
        spacing: BarLook.groupGap

        ColumnLayout {
            Layout.fillWidth: true
            spacing: BarLook.gap
            Icon {
                Layout.alignment: Qt.AlignHCenter
                icon: Icons.kanban
                size: Math.round(Space.xxl * BarLook.fontScale)
                tone: "secondary"
            }
            AiText {
                Layout.alignment: Qt.AlignHCenter
                role: "title"
                text: I18n.t("ai.tasks.empty_title")
            }
            AiText {
                role: "secondary"
                color: Type.muted
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: I18n.t("ai.tasks.empty_hint")
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Space.s
            Repeater {
                model: root.templates.slice(0, 6)
                delegate: Chip {
                    id: chip
                    required property var modelData
                    icon: Icons.lightningBolt
                    text: "/" + chip.modelData.id
                    mono: true
                    onClicked: root.templateChosen("/" + chip.modelData.id + " ")
                }
            }
        }

        AiText {
            role: "caption"
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: I18n.t("ai.tasks.keys_hint")
        }
    }
}
