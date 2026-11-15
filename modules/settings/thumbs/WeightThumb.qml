pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Card picture of an icon weight (theme.icons.weight): four shell icons,
// two by two and as big as the picture allows, drawn in the icon font of
// weight `value`.
Item {
    id: root

    property var entry
    property var value: "bold"
    readonly property string family: Icons.families[String(root.value)] || "Phosphor-Bold"

    Grid {
        // centred in the picture (the card's title is under it)
        anchors.centerIn: parent
        columns: 2
        spacing: Space.s
        Repeater {
            model: ["wifiHigh", "bell", "speakerHigh", "gear"]
            delegate: Icon {
                required property string modelData
                required property int index
                icon: Icons[modelData] ?? ""
                font.family: root.family
                size: Math.round(Math.min(root.height * 0.24, root.width * 0.3))
                tone: index === 1 ? "accent" : "text"
            }
        }
    }
}
