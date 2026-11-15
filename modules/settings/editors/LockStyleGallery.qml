pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.globals
import qs.modules.lockscreen
import qs.modules.services
import qs.modules.settings.controls
import qs.modules.settings.store
import "../../lockscreen/styles/LockStyleRegistry.js" as LockStyles
import "../controls/PictureGrid.js" as PictureGrid
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
    // A strip (in a card of the page row, SettingRow.fillHeight): one
    // horizontal row of equal pictures with the title inside, scrolling
    // sideways with an edge fade when they do not fit.
    property real fillHeight: 0
    readonly property bool strip: root.fillHeight > 0
    readonly property int stripCount: LockStyles.styles.length
    readonly property real stripWidth: root.stripCount * Space.px(96) + Space.m * (root.stripCount + 1) <= root.width ? (root.width - Space.m * (root.stripCount + 1)) / Math.max(1, root.stripCount) : (root.width - Space.m * 2) / (Math.max(1, Math.floor((root.width - Space.m * 2) / Space.px(96))) + 0.4) - Space.m
    readonly property int columns: root.strip ? root.stripCount : PictureGrid.columns(width, Space.m, root.stripCount, Space.px(150))
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
    // A capture cannot happen while the window is hidden (grabToImage
    // refuses, or its callback waits for a frame that never comes): the
    // picture in progress pauses and is taken again once it shows.
    property bool stalled: false
    readonly property bool canGrab: root.visible && root.Window.window !== null && root.Window.window.visible
    onCanGrabChanged: {
        if (root.canGrab && root.stalled) {
            root.stalled = false;
            const b = root.building;
            root.building = -1;
            Qt.callLater(() => root.building = b);
        }
    }
    // What the pictures show: a change pictures them again.
    readonly property string look: JSON.stringify([root.wallpaper, SettingsStore.get("lockscreen.tone"), SettingsStore.get("lockscreen.position"), SettingsStore.get("lockscreen.showMedia"), SettingsStore.get("lockscreen.showStatus"), SettingsStore.get("theme.lightMode")])
    // The styles in the order they are pictured: the chosen one first,
    // then the others as the strip shows them; a style already pictured
    // this session for the same look (LockShots) is skipped, its picture
    // shows at once.
    property var order: []
    function startRound() {
        const ids = LockStyles.styles.map(st => st.id);
        root.order = [root.current].concat(ids.filter(id => id !== root.current));
        root.building = -1;
        root.building = root.skipDone(0);
    }
    function skipDone(from) {
        let i = from;
        while (i < root.order.length && LockShots.get(root.order[i], root.look) !== null)
            i++;
        return i;
    }
    function advance() {
        root.building = root.skipDone(root.building + 1);
    }
    onLookChanged: root.startRound()
    Component.onCompleted: root.startRound()

    implicitHeight: root.strip ? root.fillHeight : grid.implicitHeight

    Flickable {
        id: stripFlick
        objectName: "pictureStrip"
        width: parent.width
        height: grid.height + (root.strip ? Space.m * 2 : 0)
        contentWidth: grid.width + (root.strip ? Space.m * 2 : 0)
        interactive: root.strip && contentWidth > width
        clip: root.strip
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        Grid {
            id: grid
            width: root.strip ? implicitWidth : stripFlick.width
            // inset: the ring, glow and lift of a picture never clip
            x: root.strip ? Space.m : 0
            y: root.strip ? Space.m : 0
            columns: root.columns
            spacing: Space.m

            Repeater {
                model: LockStyles.styles

                delegate: ChoiceCard {
                    id: card
                    required property var modelData
                    required property int index
                    width: root.strip ? root.stripWidth : PictureGrid.cardWidth(grid.width, grid.spacing, root.columns, Space.px(200))
                    previewHeight: root.strip ? root.fillHeight - Space.m * 2 : Math.round(width * root.screen.height / root.screen.width)
                    inset: root.strip
                    selected: root.current === modelData.id
                    title: I18n.t(modelData.labelKey)
                    onClicked: SettingsStore.set("lockscreen.style", modelData.id)

                    Item {
                        id: shot
                        objectName: "lockPreview:" + card.modelData.id
                        readonly property bool live: root.building >= 0 && root.order[root.building] === card.modelData.id
                        // the still picture: this session's for this look,
                        // else the last one taken (until it is retaken)
                        readonly property var cached: LockShots.get(card.modelData.id, root.look)
                        property var last: null
                        onCachedChanged: if (shot.cached)
                            shot.last = shot.cached
                        readonly property var grabbed: shot.cached || shot.last
                        anchors.fill: parent

                        // until its picture is taken: a quiet placeholder
                        // (a slow pulse; none with animations off), then
                        // the picture fades in over it
                        Mark {
                            id: waiting
                            objectName: "lockPreviewWaiting"
                            anchors.fill: parent
                            radius: 0
                            visible: picture.status !== Image.Ready
                            color: Look.raisedFill(false)
                            SequentialAnimation on opacity {
                                running: waiting.visible && Motion.base > 0
                                loops: Animation.Infinite
                                NumberAnimation {
                                    from: 1
                                    to: 0.5
                                    duration: Motion.palette
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    from: 0.5
                                    to: 1
                                    duration: Motion.palette
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                        Image {
                            id: picture
                            anchors.fill: parent
                            source: shot.grabbed ? shot.grabbed.url : ""
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity {
                                enabled: Motion.glide.duration > 0
                                NumberAnimation {
                                    duration: Motion.glide.duration
                                    easing.type: Motion.glide.easing
                                }
                            }
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
                            interval: 600
                            onTriggered: {
                                if (!liveView.item) {
                                    root.advance();
                                    return;
                                }
                                if (!root.canGrab) {
                                    root.stalled = true;
                                    return;
                                }
                                const ok = (liveView.item as Item).grabToImage(result => {
                                    LockShots.put(card.modelData.id, root.look, result);
                                    if (shot.live)
                                        root.advance();
                                }, Qt.size(Math.max(1, shot.width * 2), Math.max(1, shot.height * 2)));
                                if (!ok)
                                    root.stalled = true;
                            }
                        }
                    }
                }
            }
        }
    }
    StripFade {
        flick: stripFlick
        visible: root.strip
    }
}
