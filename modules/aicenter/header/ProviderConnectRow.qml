pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// A provider without a connection in the model picker:
// `OpenAI — not connected  [Connect]`.
StyledRect {
    id: root

    property var provider: ({})
    property bool selected: false

    signal connectRequested

    implicitHeight: 38
    radius: Styling.radius(-6)
    variant: selected ? "focus" : (hover.hovered ? "common" : "transparent")

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: root.connectRequested()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 6
        spacing: 10
        Image {
            visible: !!root.provider.icon
            source: root.provider.icon ? Qt.resolvedUrl("../../../assets/aiproviders/" + root.provider.icon) : ""
            sourceSize: Qt.size(18, 18)
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            opacity: 0.45
        }
        Text {
            visible: !root.provider.icon
            Layout.preferredWidth: 18
            horizontalAlignment: Text.AlignHCenter
            text: Icons.plug
            font.family: Icons.font
            font.pixelSize: 15
            color: Colors.outline
        }
        Text {
            Layout.fillWidth: true
            text: (root.provider.label || root.provider.id || "") + "  —  " + I18n.t("ai.not_connected")
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.outline
        }
        Chip {
            objectName: "connect_" + (root.provider.id || "")
            implicitHeight: 24
            glyph: Icons.plug
            label: I18n.t("ai.connect")
            onClicked: root.connectRequested()
        }
    }
}
