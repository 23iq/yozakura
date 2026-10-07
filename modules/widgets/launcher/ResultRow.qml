pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// One launcher result as a kit ListRow: the result icon, the title and a
// one-line subtitle (description / path / command). At rest the trailing
// slot shows the provider badge; the selected row shows what Enter does and
// the ↵ key. `cards` gives the row more air and a bigger icon.
ListRow {
    id: row

    required property var result
    property bool expanded: false
    property bool cards: false
    // Narrow list beside the detail pane: the ↵ key without its label.
    property bool narrow: false
    readonly property bool inert: !!row.result.inert
    // layout.launcher.icons = false: a text-only (command-line) list; the
    // title then starts at the row's edge.
    property bool showIcon: Config.layout.launcher.icons !== false
    readonly property int iconSize: row.cards ? Math.round(Metrics.iconSize * 1.375) : Metrics.iconSize
    // Where the title starts, relative to the row's content edge.
    readonly property int textInset: row.showIcon ? row.iconSize + Space.m : 0

    title: row.result.title || ""
    subtitle: row.result.subtitle || ""

    leading: row.showIcon ? icon : null

    Component {
        id: icon
        ResultIcon {
            objectName: "resultIcon"
            item: row.result
            size: row.iconSize
        }
    }

    trailing: Component {
        Row {
            spacing: Space.s
            visible: !row.inert

            KitText {
                id: badge
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                visible: !row.selected && text !== ""
                // The section label already names the provider.
                text: row.result.badge && row.result.badge !== I18n.t("launcher.provider." + row.result.provider) ? row.result.badge : ""
            }

            KitText {
                id: hint
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                color: Type.secondary
                visible: row.selected && !row.expanded && !row.narrow && text !== ""
                text: row.result.hint || ""
            }

            KeyHint {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.selected && !row.expanded && hint.text !== ""
                icon: Icons.arrowElbowDownLeft
            }
        }
    }
}
