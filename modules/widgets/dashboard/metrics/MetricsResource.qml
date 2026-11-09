pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit

// One resource meter: its glyph and a progress line in the resource's
// series colour (the colour of its chart line), over a caption line with
// the name, the value and an optional temperature.
Column {
    id: root

    property string icon: ""
    property real value: 0
    property color seriesColor: Type.progress
    property string name: ""
    property string valueText: ""
    // Degrees, < 0 = no sensor
    property real temperature: -1

    spacing: Space.xs

    RowLayout {
        width: parent.width
        spacing: Space.s

        Icon {
            icon: root.icon
            role: "body"
            tone: "secondary"
            Layout.preferredWidth: Type.iconSize("body")
        }

        ProgressLine {
            objectName: "resourceLine"
            Layout.fillWidth: true
            implicitHeight: Space.xs
            value: root.value
            fillColor: root.seriesColor
        }
    }

    RowLayout {
        width: parent.width
        spacing: Space.xs

        KitText {
            Layout.maximumWidth: parent.width * 0.6
            role: "caption"
            color: Type.secondary
            text: root.name
            elide: Text.ElideMiddle
        }

        // A hairline leader to the value (just room where dividers are off)
        Item {
            Layout.fillWidth: true
            implicitHeight: Space.hairline

            Divider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
            }
        }

        KitText {
            role: "caption"
            tabular: true
            color: Type.text
            text: root.valueText
        }

        Icon {
            visible: root.temperature >= 0
            icon: Icons.temperature
            role: "caption"
            color: root.seriesColor
        }

        KitText {
            visible: root.temperature >= 0
            role: "caption"
            tabular: true
            color: Type.text
            text: `${root.temperature}°`
        }
    }
}
