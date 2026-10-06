pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.aicenter.common

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
            Glyph {
                Layout.alignment: Qt.AlignHCenter
                text: Icons.kanban
                size: 18
                role: "primary"
            }
            UiText {
                Layout.alignment: Qt.AlignHCenter
                text: I18n.t("ai.tasks.empty_title")
                size: 6
                strong: true
                color: Colors.overBackground
            }
            UiText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: I18n.t("ai.tasks.empty_hint")
                muted: true
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: root.templates.slice(0, 6)
                delegate: Chip {
                    id: chip
                    required property var modelData
                    glyph: Icons.lightningBolt
                    label: "/" + chip.modelData.id
                    mono: true
                    onClicked: root.templateChosen("/" + chip.modelData.id + " ")
                }
            }
        }

        UiText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: I18n.t("ai.tasks.keys_hint")
            muted: true
            size: -3
        }
    }
}
