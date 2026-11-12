pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Stage of the Lock screen page: your lock screen as it will look, from
// the live config: the wallpaper blurred as much as `lockscreen.blur`
// asks, the clock, the password field at the top or the bottom
// (`lockscreen.position`; a click on the other half moves it there), the
// status strip and the now-playing card when they are on. Rows light up
// their part.
Stage {
    id: stage

    readonly property real blurAmount: Math.max(0, Math.min(1, Number(SettingsStore.get("lockscreen.blur") ?? 0.6)))
    readonly property bool fieldTop: SettingsStore.get("lockscreen.position") === "top"
    readonly property bool status: SettingsStore.get("lockscreen.showStatus") !== false
    readonly property bool media: SettingsStore.get("lockscreen.showMedia") !== false
    readonly property real u: Math.max(Space.px(10), stage.height * 0.045)

    stageHeight: Space.px(300)
    imageScale: 1.04 + stage.blurAmount * 0.08

    // the blur over the wallpaper, as strong as the setting
    Item {
        id: frost
        anchors.fill: parent
        layer.enabled: stage.blurAmount > 0.02
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: stage.blurAmount
            blurMax: 48
        }
        Image {
            anchors.fill: parent
            visible: frost.layer.enabled
            source: stage.wallpaper
            sourceSize.width: 160
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }
    Mark {
        anchors.fill: parent
        radius: stage.radius
        color: Qt.alpha(Colors.shadow, 0.28)
    }

    // the status strip
    Row {
        id: statusRow
        visible: stage.status
        anchors.right: parent.right
        anchors.rightMargin: stage.u
        y: stage.u * 0.7
        spacing: stage.u * 0.6
        Repeater {
            model: ["wifiHigh", "speakerHigh", "batteryHigh"]
            delegate: Icon {
                required property string modelData
                icon: Icons[modelData] ?? ""
                size: Math.round(stage.u * 1.1)
                tone: "text"
            }
        }
    }
    StageSpot {
        anchors.fill: statusRow
        visible: stage.status
        keys: ["lockscreen.showStatus"]
    }

    // the clock
    KitText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: stage.fieldTop ? parent.height * 0.42 : parent.height * 0.18
        role: "display"
        font.pixelSize: Math.round(stage.u * 4.2)
        font.weight: Font.Light
        color: Qt.rgba(1, 1, 1, 0.95)
        text: "21:47"
        Behavior on y {
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }
    }

    // the password field
    Mark {
        id: field
        objectName: "lockField"
        width: parent.width * 0.3
        height: stage.u * 2.2
        x: (parent.width - width) / 2
        y: stage.fieldTop ? stage.u * 2.6 : parent.height - height - stage.u * 2.2
        radius: height / 2
        color: Qt.alpha(Colors.surface, 0.72)
        border.width: Space.hairline
        border.color: Qt.rgba(1, 1, 1, 0.25)
        Behavior on y {
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }
        Row {
            anchors.centerIn: parent
            spacing: stage.u * 0.5
            Repeater {
                model: 6
                delegate: Mark {
                    width: stage.u * 0.5
                    height: width
                    color: Qt.rgba(1, 1, 1, 0.8)
                }
            }
        }
        StageSpot {
            keys: ["lockscreen.position"]
            cornerRadius: field.radius
        }
    }

    // now playing
    Mark {
        id: player
        visible: stage.media
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
