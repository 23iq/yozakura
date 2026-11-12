pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.globals
import qs.modules.lockscreen
import qs.modules.services
import qs.modules.settings.controls
import qs.modules.settings.store
import "../../lockscreen/styles/LockStyleRegistry.js" as LockStyles
import qs.modules.components.kit

// Lock screen style gallery: every style of the registry pictured by the
// real lock screen view (LockView in preview mode: no focus, no cava), over
// your wallpaper, with your tone, position and media settings. The views
// are built one after the other and each is captured to a still picture
// once it has revealed (grabToImage), then destroyed: the page costs one
// lock screen at a time while it opens and nothing once it is drawn (the
// six live, animated full-size views it used to keep cost ~200 ms per
// visit and warned when torn down). A change of what they show (wallpaper,
// tone, position, media, status) pictures them again.
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
    // The style being pictured (index into LockStyles.styles); past the
    // end: all done.
    property int building: 0
    // What the pictures show: a change pictures them again.
    readonly property string look: JSON.stringify([root.wallpaper, SettingsStore.get("lockscreen.tone"), SettingsStore.get("lockscreen.position"), SettingsStore.get("lockscreen.showMedia"), SettingsStore.get("lockscreen.showStatus"), SettingsStore.get("theme.lightMode")])
    onLookChanged: root.building = 0

    implicitHeight: grid.implicitHeight

    Grid {
        id: grid
        width: parent.width
        columns: root.columns
        spacing: Space.m

        Repeater {
            model: LockStyles.styles

            delegate: ChoiceCard {
                id: card
                required property var modelData
                required property int index
                width: (grid.width - grid.spacing * (root.columns - 1)) / root.columns
                previewHeight: Math.round(width * root.screen.height / root.screen.width)
                selected: root.current === modelData.id
                title: I18n.t(modelData.labelKey)
                onClicked: SettingsStore.set("lockscreen.style", modelData.id)

                Item {
                    id: shot
                    objectName: "lockPreview:" + card.modelData.id
                    readonly property bool live: card.index === root.building
                    // the still picture of the last capture
                    property var grabbed: null
                    anchors.fill: parent

                    Image {
                        anchors.fill: parent
                        source: shot.grabbed ? shot.grabbed.url : ""
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                    }
                    Item {
                        id: stagePort
                        width: root.screen.width
                        height: root.screen.height
                        scale: shot.width / root.screen.width
                        transformOrigin: Item.TopLeft
                        // Clicks go to the card, never to the preview's field.
                        enabled: false

                        Loader {
                            id: liveView
                            anchors.fill: parent
                            active: shot.live
                            sourceComponent: LockView {
                                preview: true
                                startAnim: true
                                styleId: card.modelData.id
                                username: Brand.home.split("/").pop()
                                hostname: Brand.appId
                                wallpaperSource: root.wallpaper
                            }
                            onLoaded: settle.restart()
                        }
                    }
                    // Captured once the reveal and the wallpaper settled.
                    Timer {
                        id: settle
                        interval: 900
                        onTriggered: {
                            if (!liveView.item) {
                                root.building++;
                                return;
                            }
                            (liveView.item as Item).grabToImage(result => {
                                shot.grabbed = result;
                                if (shot.live)
                                    root.building++;
                            }, Qt.size(Math.max(1, shot.width * 2), Math.max(1, shot.height * 2)));
                        }
                    }
                }
            }
        }
    }
}
