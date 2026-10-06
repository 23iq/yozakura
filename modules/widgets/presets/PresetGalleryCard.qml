import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.settings.presets

// One gallery card: the preset's thumbnail (PresetThumb, the miniature shell
// on the current wallpaper) and its name. Hover selects and previews it,
// a click keeps it.
StyledRect {
    id: root

    required property var card
    property bool selected: false

    signal hovered
    signal clicked

    variant: selected ? "focus" : "common"
    radius: Styling.radius(4)
    scale: selected ? 1 : 0.97

    Behavior on scale {
        enabled: Motion.enter.duration > 0
        NumberAnimation {
            duration: Motion.enter.duration
            easing.type: Motion.enter.easing
        }
    }

    PresetThumb {
        id: thumb
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Metrics.spacing
        height: Math.round(width * 10 / 16)
        look: root.card ? root.card.look : null
    }

    Row {
        anchors.top: thumb.bottom
        anchors.topMargin: Metrics.spacing
        anchors.left: thumb.left
        anchors.right: thumb.right
        spacing: Metrics.spacing / 2

        Text {
            width: parent.width - (badge.visible ? badge.width + parent.spacing : 0)
            text: root.card ? root.card.title : ""
            elide: Text.ElideRight
            color: Colors.overBackground
            font.family: Config.defaultFont
            font.pixelSize: Styling.fontSize(0)
            font.weight: root.selected ? Font.DemiBold : Font.Normal
        }

        Text {
            id: badge
            visible: !!(root.card && root.card.active)
            text: I18n.t("presets.active")
            color: Colors.primary
            font.family: Config.defaultFont
            font.pixelSize: Styling.fontSize(-2)
            font.weight: Font.Bold
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered()
        onClicked: root.clicked()
    }
}
