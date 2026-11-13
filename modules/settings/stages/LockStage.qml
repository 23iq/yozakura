pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.globals
import qs.modules.lockscreen
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Stage of the Lock screen page: your lock screen itself, the real LockView
// (preview mode: no focus, no cava) in the chosen style over your
// wallpaper, from the live config: blur, tone, the password field at the
// top or the bottom (a click on the other half moves it there), the status
// line and the now-playing card. Like the style pictures (LockStyleGallery)
// it is built, captured once it has revealed (grabToImage) and destroyed: a
// change shows the live view at once and pictures it again; the page keeps
// no lock screen alive. Rows light up their part.
Stage {
    id: stage
    objectName: "lockStage"

    readonly property bool fieldTop: SettingsStore.get("lockscreen.position") === "top"
    readonly property bool status: SettingsStore.get("lockscreen.showStatus") !== false
    readonly property bool media: SettingsStore.get("lockscreen.showMedia") !== false
    // no player: the lock screen draws no card; the stage shows where it goes
    readonly property bool noPlayer: MprisController.activePlayer === null || MprisController.activePlayer === undefined
    readonly property real u: Math.max(Space.px(10), stage.height * 0.045)
    // the virtual screen the view is laid out on, scaled into the stage
    readonly property size screen: Qt.size(1600, 900)
    // the wallpaper as the lock screen gets it (a video as its still)
    readonly property string lockWallpaper: {
        const m = GlobalStates.wallpaperManager;
        if (!m)
            return "";
        const path = m.effectiveWallpaper ?? m.currentWallpaper ?? "";
        const shown = path && m.getDisplaySource ? m.getDisplaySource(path) : path;
        return shown ? "file://" + shown : "";
    }
    // what the picture shows: a change pictures it again
    readonly property string look: JSON.stringify([stage.lockWallpaper, SettingsStore.get("lockscreen.style"), SettingsStore.get("lockscreen.tone"), SettingsStore.get("lockscreen.blur"), SettingsStore.get("lockscreen.position"), SettingsStore.get("lockscreen.showMedia"), SettingsStore.get("lockscreen.showVisualizer"), SettingsStore.get("lockscreen.showStatus"), SettingsStore.get("theme.lightMode"), Math.round(stage.width), Math.round(stage.height)])
    // a change: the live view at once (it follows the config), pictured
    // again once it settled
    onLookChanged: {
        stage.live = true;
        if (liveView.item)
            settle.restart();
    }
    // the view exists (building or rebuilding the picture)
    property bool live: true
    property var grabbed: null
    readonly property bool canGrab: stage.visible && stage.Window.window !== null && stage.Window.window.visible
    onCanGrabChanged: if (stage.canGrab && stage.live)
        settle.restart()

    stageHeight: Space.px(300)
    // the lock screen draws its own wallpaper
    backdrop: false

    Item {
        id: shot
        objectName: "lockShot"
        anchors.fill: parent

        Image {
            id: still
            anchors.fill: parent
            visible: !stage.live || liveView.status !== Loader.Ready
            source: stage.grabbed ? stage.grabbed.url : ""
            fillMode: Image.PreserveAspectCrop
            smooth: true
        }

        // the view, laid out on the virtual screen, cropped to the stage
        Item {
            id: port
            readonly property real fit: Math.max(shot.width / stage.screen.width, shot.height / stage.screen.height)
            width: stage.screen.width
            height: stage.screen.height
            x: (shot.width - width * fit) / 2
            y: (shot.height - height * fit) / 2
            scale: fit
            transformOrigin: Item.TopLeft
            // clicks go to the stage, never to the preview's field
            enabled: false

            Loader {
                id: liveView
                objectName: "lockView"
                anchors.fill: parent
                active: stage.live
                sourceComponent: LockView {
                    preview: true
                    startAnim: true
                    username: Brand.home.split("/").pop()
                    hostname: Brand.appId
                    wallpaperSource: stage.lockWallpaper
                }
                onLoaded: settle.restart()
            }
        }
        clip: true
    }

    // captured once the reveal and the wallpaper settled, then destroyed
    Timer {
        id: settle
        interval: 900
        onTriggered: {
            if (!liveView.item || !stage.canGrab)
                return;
            const ok = shot.grabToImage(result => {
                stage.grabbed = result;
                stage.live = false;
            }, Qt.size(Math.max(1, shot.width * 2), Math.max(1, shot.height * 2)));
            if (!ok)
                settle.restart();
        }
    }

    // the status line
    Item {
        id: statusSpot
        visible: stage.status
        anchors.right: parent.right
        width: parent.width * 0.3
        height: stage.u * 2.2
        StageSpot {
            keys: ["lockscreen.showStatus"]
        }
    }

    // the password field's half
    Item {
        id: field
        objectName: "lockField"
        width: parent.width * 0.34
        height: stage.u * 2.6
        x: (parent.width - width) / 2
        y: stage.fieldTop ? stage.u * 2.2 : parent.height - height - stage.u * 1.6
        StageSpot {
            keys: ["lockscreen.position"]
            cornerRadius: field.height / 2
        }
    }

    // where the now-playing card goes when nothing plays
    Mark {
        id: player
        visible: stage.media && stage.noPlayer
        width: parent.width * 0.26
        height: stage.u * 3
        x: stage.u
        y: parent.height - height - stage.u
        radius: Look.radius("box", height)
        color: Qt.alpha(Colors.surface, 0.6)
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: stage.u * 0.6
            spacing: stage.u * 0.6
            Mark {
                width: stage.u * 2
                height: width
                radius: Look.radius("small", height)
                color: Colors.primary
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: stage.u * 0.3
                Mark {
                    width: player.width * 0.4
                    height: stage.u * 0.35
                    color: Qt.rgba(1, 1, 1, 0.75)
                }
                Mark {
                    width: player.width * 0.28
                    height: stage.u * 0.3
                    color: Qt.rgba(1, 1, 1, 0.4)
                }
            }
        }
    }
    Item {
        anchors.fill: player
        visible: stage.media
        StageSpot {
            keys: ["lockscreen.showMedia", "lockscreen.showVisualizer"]
            cornerRadius: player.radius
        }
    }

    // direct manipulation: a click on the other half moves the field there
    MouseArea {
        objectName: "lockMoveField"
        x: 0
        y: stage.fieldTop ? parent.height / 2 : 0
        width: parent.width
        height: parent.height / 2
        cursorShape: Qt.PointingHandCursor
        onClicked: SettingsStore.transaction("prefs.undo.field_moved", () => SettingsStore.set("lockscreen.position", stage.fieldTop ? "bottom" : "top"))
    }
}
