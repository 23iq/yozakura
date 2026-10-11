pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.components.kit

// Screens that keep their own wallpaper (perScreenWallpapers): choosing a
// wallpaper in the grid sets the shared one, which these screens do not
// show. Lists each assignment with a way back to the shared wallpaper, and
// "apply to all" clears them all.
Column {
    id: root

    readonly property var manager: GlobalStates.wallpaperManager
    readonly property var assigned: manager && manager.perScreenWallpapers ? manager.perScreenWallpapers : ({})
    readonly property var screens: Object.keys(assigned).filter(n => !!assigned[n])

    visible: screens.length > 0
    spacing: Space.s

    function fileName(path) {
        return path ? path.substring(path.lastIndexOf("/") + 1) : "";
    }

    Row {
        width: parent.width
        spacing: Space.m

        SectionLabel {
            width: parent.width - allButton.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t("prefs.wall.per_screen")
        }
        Chip {
            id: allButton
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.image
            text: I18n.t("prefs.wall.apply_all")
            onClicked: root.manager.clearAllPerScreenWallpapers()
        }
    }

    Repeater {
        model: root.screens

        delegate: ListRow {
            id: row
            required property string modelData
            width: root.width
            title: modelData
            subtitle: root.fileName(root.assigned[modelData])
            trailing: Component {
                IconButton {
                    icon: Icons.cancel
                    size: "s"
                    onClicked: root.manager.clearPerScreenWallpaper(row.modelData)
                }
            }
        }
    }
}
