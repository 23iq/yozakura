pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Home tile scene of Launcher: a tiny search field over a few results.
Mark {
    id: scene

    required property Card tile

    height: Math.min(parent ? parent.height : 0, col.implicitHeight + Space.m * 2)
    radius: Look.radius("box", Space.controlL)
    color: Look.raisedFill(false)

    Column {
        id: col
        x: Space.m
        y: Space.m
        width: scene.width - Space.m * 2
        spacing: Space.s
        Row {
            spacing: Space.s
            Icon {
                icon: Icons.magnifyingGlass
                role: "caption"
                tone: "muted"
            }
            KitText {
                role: "caption"
                color: Type.secondary
                text: "fire"
            }
        }
        Repeater {
            model: [["Firefox", Colors.primary], [I18n.t("prefs.home.result_files"), Colors.tertiary], ["12 × 4 = 48", Colors.secondary]]
            delegate: Row {
                required property var modelData
                spacing: Space.s
                Mark {
                    width: Space.l
                    height: width
                    radius: Look.radius("small", height)
                    color: parent.modelData[1]
                }
                KitText {
                    role: "body"
                    text: parent.modelData[0]
                }
            }
        }
    }
}
