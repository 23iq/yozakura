pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.settings.store
import "../HomeStatus.js" as HomeStatus

// Home tile scene of Notifications & focus: a toast over two more stacked
// behind it, shaped as they show now (a card in a corner, on its side; a
// pill out of the island; a strip), an app icon, a title and a line. Do
// not disturb hushes them: the stack fades back and a moon sits on it.
Item {
    id: scene

    required property Card tile

    readonly property var note: HomeStatus.notificationState({
        "get": k => SettingsStore.get(k)
    })
    readonly property bool dnd: scene.note.dnd
    readonly property bool pill: scene.note.presentation === "notch"
    readonly property bool strip: scene.note.presentation === "strips"
    // the corner's side: the stack leans that way
    readonly property bool leftSide: String(scene.note.position).indexOf("left") >= 0 && !scene.pill
    readonly property bool rightSide: String(scene.note.position).indexOf("right") >= 0
    readonly property real toastH: Math.round(Math.min(scene.height * 0.62, Space.controlL))
    readonly property real toastW: scene.strip ? scene.width : Math.round(Math.min(scene.width, scene.toastH * 3.6))

    Item {
        id: stack
        width: scene.toastW
        height: scene.toastH + Space.s * 2
        x: scene.leftSide || scene.strip ? 0 : scene.rightSide && !scene.pill ? scene.width - width : Math.round((scene.width - width) / 2)
        y: Math.round((scene.height - height) / 2)
        opacity: scene.dnd ? 0.4 : 1
        Behavior on opacity {
            enabled: Motion.glide.duration > 0
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }

        // the two behind it, smaller and fainter
        Repeater {
            model: 2
            delegate: Mark {
                id: back
                required property int index
                readonly property int depth: 2 - back.index
                width: stack.width * (1 - back.depth * 0.08)
                height: scene.toastH
                x: Math.round((stack.width - width) / 2)
                y: Space.s * 2 - back.depth * Space.s + (scene.tile.hovered ? -back.depth * Space.xs : 0)
                radius: toast.radius
                color: Look.raisedFill(false)
                opacity: 1 - back.depth * 0.3
                border.width: Space.hairline
                border.color: Type.hairline
                Behavior on y {
                    enabled: Motion.glide.duration > 0
                    NumberAnimation {
                        duration: Motion.glide.duration
                        easing.type: Motion.glide.easing
                    }
                }
            }
        }

        Mark {
            id: toast
            y: Space.s * 2
            width: stack.width
            height: scene.toastH
            radius: scene.pill ? height / 2 : Look.radius("surface", height)
            color: scene.pill ? Colors.background : Look.raisedFill(false)
            border.width: Space.hairline
            border.color: Type.hairline

            Mark {
                id: app
                x: scene.pill ? Math.round((toast.height - height) / 2) : Space.s
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(toast.height * 0.56)
                height: width
                radius: Look.radius("control", height)
                color: Look.tonal(Type.accent)
                Icon {
                    anchors.centerIn: parent
                    icon: Icons.chatDots
                    size: Math.round(app.height * 0.56)
                    tone: "accent"
                }
            }
            Column {
                x: app.x + app.width + Space.s
                anchors.verticalCenter: parent.verticalCenter
                width: toast.width - x - (scene.pill ? toast.height / 2 : Space.s)
                spacing: Space.xs
                Mark {
                    width: parent.width * 0.5
                    height: Math.max(Space.xs, Math.round(toast.height * 0.12))
                    color: Type.secondary
                }
                Mark {
                    width: parent.width * 0.85
                    height: Math.max(Space.xs, Math.round(toast.height * 0.1))
                    color: Type.track
                }
            }
        }
    }

    // do not disturb: a moon on the hushed stack
    Mark {
        visible: scene.dnd
        width: Math.round(scene.toastH * 0.7)
        height: width
        x: Math.round(stack.x + (stack.width - width) / 2)
        y: Math.round(stack.y + toast.y + (scene.toastH - height) / 2)
        color: Type.accent
        Icon {
            anchors.centerIn: parent
            icon: Icons.moon
            size: Math.round(parent.height * 0.56)
            tone: "accentInk"
        }
    }
}
