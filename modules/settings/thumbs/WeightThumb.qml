pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Card picture of an icon weight (theme.icons.weight): a row of shell icons
// drawn in the icon font of weight `value`.
Item {
    id: root

    property var entry
    property var value: "bold"
    readonly property string family: Icons.families[String(root.value)] || "Phosphor-Bold"

    Row {
        anchors.centerIn: parent
        spacing: Space.m
        Repeater {
            model: ["wifiHigh", "bell", "speakerHigh", "gear"]
            delegate: Icon {
                required property string modelData
                required property int index
                icon: Icons[modelData] ?? ""
                font.family: root.family
                size: Math.round(Math.min(root.height * 0.3, root.width * 0.13))
                tone: index === 1 ? "accent" : "text"
            }
        }
    }
}
