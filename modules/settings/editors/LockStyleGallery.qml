pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.globals
import qs.modules.lockscreen
import qs.modules.services
import qs.modules.settings.controls
import qs.modules.settings.store
import "../../lockscreen/styles/LockStyleRegistry.js" as LockStyles

// Lock screen style gallery: every style of the registry rendered live by
// the real lock screen view (LockView in preview mode: no focus, no cava),
// over your wallpaper, with your tone, position and media settings.
Item {
    id: root

    property var entry
    readonly property string current: SettingsStore.get("lockscreen.style") ?? LockStyles.DEFAULT_ID
    readonly property int columns: width < 560 ? 1 : (width < 920 ? 2 : 3)
    readonly property var manager: GlobalStates.wallpaperManager
    readonly property string wallpaper: {
        const m = root.manager;
        if (!m)
            return "";
        const path = m.effectiveWallpaper ?? m.currentWallpaper ?? "";
        // Thumbnails: videos stay still and the previews stay light.
        const shown = path && m.getDisplaySource ? m.getDisplaySource(path) : path;
        return shown ? "file://" + shown : "";
    }
    // Every preview is laid out on this virtual screen, then scaled down.
    readonly property size screen: Qt.size(1600, 900)

    implicitHeight: grid.implicitHeight

    Grid {
        id: grid
        width: parent.width
        columns: root.columns
        spacing: 12

        Repeater {
            model: LockStyles.styles

            delegate: ChoiceCard {
                id: card
                required property var modelData
                width: (grid.width - grid.spacing * (root.columns - 1)) / root.columns
                previewHeight: Math.round((width - 16) * root.screen.height / root.screen.width)
                selected: root.current === modelData.id
                icon: modelData.icon
                title: I18n.t(modelData.labelKey)
                subtitle: I18n.t(modelData.descKey)
                onClicked: SettingsStore.set("lockscreen.style", modelData.id)

                Item {
                    objectName: "lockPreview:" + card.modelData.id
                    width: root.screen.width
                    height: root.screen.height
                    scale: (card.width - 16) / root.screen.width
                    transformOrigin: Item.TopLeft
                    // Clicks go to the card, never to the preview's field.
                    enabled: false

                    LockView {
                        anchors.fill: parent
                        preview: true
                        startAnim: true
                        styleId: card.modelData.id
                        username: Brand.home.split("/").pop()
                        hostname: Brand.appId
                        wallpaperSource: root.wallpaper
                    }
                }
            }
        }
    }
}
