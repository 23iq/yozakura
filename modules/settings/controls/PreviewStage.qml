import QtQuick
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit

// Inset area that hosts a live preview, tagged "Live preview": the theme's
// recessed "internalbg" box with the kit's hairline, the tag a label-role
// caption on a small plate of the same surface.
Item {
    id: stage

    property real stageHeight: 120
    property bool showTag: true
    default property alias content: area.data

    implicitHeight: stageHeight

    StyledRect {
        id: frame
        anchors.fill: parent
        variant: "internalbg"
        radius: Look.chipRadius(Space.chip)
        enableShadow: false
        enableBorder: false

        Rectangle {
            anchors.fill: parent
            radius: frame.radius
            color: "transparent"
            border.width: Space.hairline
            border.color: Type.hairline
        }
    }

    Item {
        id: area
        anchors.fill: parent
        anchors.margins: Space.hairline
        clip: true
    }

    StyledRect {
        visible: stage.showTag
        x: Space.s
        y: Space.s
        width: tag.implicitWidth + Space.s * 2
        height: tag.implicitHeight + Space.xs
        variant: "internalbg"
        radius: Look.chipRadius(height)
        enableShadow: false
        enableBorder: false

        KitText {
            id: tag
            anchors.centerIn: parent
            role: "label"
            text: I18n.t("prefs.common.live_preview")
        }
    }
}
