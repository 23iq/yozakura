pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.components.kit

// A provider without a connection in the model picker:
// `OpenAI — not connected  [Connect]`.
StyledRect {
    id: root

    property var provider: ({})
    property bool selected: false

    signal connectRequested

    implicitHeight: 38
    radius: Look.radius("small")
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
        anchors.leftMargin: Space.s
        anchors.rightMargin: Space.s
        spacing: Space.s
        Image {
            visible: !!root.provider.icon
            source: root.provider.icon ? Qt.resolvedUrl("../../../assets/aiproviders/" + root.provider.icon) : ""
            sourceSize: Qt.size(18, 18)
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            opacity: 0.45
        }
        Icon {
            role: "secondary"
            tone: "muted"
            visible: !root.provider.icon
            Layout.preferredWidth: 18
            horizontalAlignment: Text.AlignHCenter
            icon: Icons.plug
        }
        KitText {
            role: "caption"
            Layout.fillWidth: true
            text: (root.provider.label || root.provider.id || "") + "  —  " + I18n.t("ai.not_connected")
            elide: Text.ElideRight
        }
        Chip {
            objectName: "connect_" + (root.provider.id || "")
            dense: true
            icon: Icons.plug
            text: I18n.t("ai.connect")
            onClicked: root.connectRequested()
        }
    }
}
