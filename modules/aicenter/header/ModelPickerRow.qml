pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// One model of the picker: icon, name, detail line, capability badges and
// marks for the current engine (check) and the space default (pin). A CLI
// agent is a group: `expandable` shows a caret and a tap expands its models.
StyledRect {
    id: root

    property var entry: ({})
    property bool selected: false
    property bool current: false
    property bool isDefault: false
    property bool showBadges: true
    property bool expandable: false
    property bool expanded: false

    signal activated

    readonly property bool available: entry.available !== false
    readonly property string detail: entry.kind === "local" ? I18n.t("ai.local_model") + (entry.description ? " · " + entry.description : "") : (entry.description || "")

    implicitHeight: Math.max(44, content.implicitHeight + 12)
    radius: Styling.radius(-6)
    variant: selected ? "focus" : (hover.hovered ? "common" : "transparent")
    opacity: available ? 1 : 0.5

    HoverHandler {
        id: hover
        cursorShape: root.available ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
    TapHandler {
        onTapped: root.activated()
    }

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10
        Image {
            source: root.entry.icon || ""
            sourceSize: Qt.size(18, 18)
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            opacity: root.available ? 1 : 0.4
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: root.entry.name || ""
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: root.current ? Font.DemiBold : Font.Normal
                color: Colors.overSurface
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: detailText.text.length > 0 || badges.visible
                CapabilityBadges {
                    id: badges
                    visible: root.showBadges && badges.badges.length > 0
                    info: root.entry.info || null
                }
                Text {
                    id: detailText
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.detail
                    elide: Text.ElideRight
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-4)
                    color: Colors.outline
                }
            }
        }
        Text {
            visible: root.isDefault
            text: Icons.pin
            font.family: Icons.font
            font.pixelSize: 13
            color: Colors.primary
        }
        Text {
            objectName: "pickerCaret"
            visible: root.expandable
            text: root.expanded ? Icons.caretDown : Icons.caretRight
            font.family: Icons.font
            font.pixelSize: 12
            color: Colors.outline
        }
        Text {
            visible: root.current && !(root.expandable && root.expanded)
            text: Icons.accept
            font.family: Icons.font
            font.pixelSize: 13
            color: Colors.primary
        }
    }
}
