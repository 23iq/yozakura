pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "../../services/timers/TimerFormat.js" as TimerFormat

// Stage of Timers: your screen (ScreenMini) with a Pomodoro running. The
// island shows it as the shell does (a ring that empties, or the time
// alone; seconds or minutes; the stopwatch beside it), the Pomodoro dial
// shows the focus and break lengths as one circle (a loop when the next
// phase starts on its own), and two cards show what happens when time is
// up (the alarm: pulse, sound, the panel with its buttons) and in focus
// mode (Do Not Disturb, no badges). A click on the island's time shows or
// hides the seconds; rows light up their part.
Stage {
    id: stage

    readonly property real u: mini.unit
    // a shell surface on the miniature (opaque enough over the wallpaper)
    readonly property color surface: Qt.alpha(Colors.surfaceContainer, 0.92)
    readonly property bool seconds: SettingsStore.get("system.timers.showSeconds") !== false
    readonly property bool stopwatch: SettingsStore.get("system.timers.showStopwatch") !== false
    readonly property bool ring: SettingsStore.get("system.timers.notchStyle") !== "text"
    readonly property real work: Math.max(60, Number(SettingsStore.get("system.pomodoro.workTime") ?? 1500))
    readonly property real rest: Math.max(60, Number(SettingsStore.get("system.pomodoro.restTime") ?? 300))
    readonly property bool autoStart: SettingsStore.get("system.pomodoro.autoStart") === true
    readonly property bool pulse: SettingsStore.get("system.timers.pulseOnFinish") !== false
    readonly property bool panel: SettingsStore.get("system.timers.alarmPanel") !== false
    readonly property bool sound: SettingsStore.get("system.timers.sound") !== false
    readonly property int focusMin: Number(SettingsStore.get("system.focus.minutes") ?? 50)
    readonly property bool focusDnd: SettingsStore.get("system.focus.dnd") !== false
    readonly property bool focusBadges: SettingsStore.get("system.focus.hideBadges") !== false
    // a Pomodoro a few seconds in
    readonly property real leftMs: (stage.work - 1) * 1000

    stageHeight: Space.px(300)

    ScreenMini {
        id: mini
        anchors.fill: parent
        barOpacity: stage.barOpacity
        cornerRadius: stage.radius
        showIsland: false
        showDock: false
        showWindows: false

        // The island with the running Pomodoro (and the stopwatch).
        Mark {
            id: island
            objectName: "timersIsland"
            readonly property bool atBottom: mini.islandEdge === "bottom"
            width: islandRow.implicitWidth + stage.u * 1.2
            height: Math.round(stage.u * 1.5)
            x: Math.round((mini.width - width) / 2)
            y: atBottom ? mini.height - height - Space.xs - Math.max(0, (mini.depths.bottom || 0) - height) / 2 : Space.xs + Math.max(0, (mini.depths.top || 0) - height) / 2
            radius: height / 2
            color: Colors.surfaceContainerLowest
            border.width: Space.hairline
            border.color: Qt.alpha(Colors.outlineVariant, 0.7)
            Behavior on width {
                enabled: Motion.glide.duration > 0
                NumberAnimation {
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }

            Row {
                id: islandRow
                anchors.centerIn: parent
                spacing: Math.round(stage.u * 0.35)
                Ring {
                    visible: stage.ring
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(stage.u * 0.95)
                    height: width
                    thickness: Math.max(2, Math.round(stage.u * 0.14))
                    value: 0.82
                }
                Icon {
                    visible: !stage.ring
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.countdown
                    size: Math.round(stage.u * 0.75)
                    tone: "accent"
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "body"
                    tabular: true
                    font.pixelSize: Math.round(stage.u * 0.62)
                    font.weight: Font.Medium
                    text: TimerFormat.label(stage.leftMs, stage.seconds)
                }
                Mark {
                    visible: stage.stopwatch
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(1, Space.hairline)
                    height: Math.round(stage.u * 0.7)
                    radius: 0
                    color: Type.hairline
                }
                Icon {
                    visible: stage.stopwatch
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.watch
                    size: Math.round(stage.u * 0.7)
                    tone: "secondary"
                }
                KitText {
                    visible: stage.stopwatch
                    anchors.verticalCenter: parent.verticalCenter
                    role: "body"
                    tabular: true
                    font.pixelSize: Math.round(stage.u * 0.62)
                    color: Type.secondary
                    text: TimerFormat.label(724000, stage.seconds)
                }
            }
            MouseArea {
                objectName: "timersSecondsFlip"
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: SettingsStore.transaction("prefs.undo.timer_seconds", () => SettingsStore.set("system.timers.showSeconds", !stage.seconds))
            }
        }
        StageSpot {
            anchors.fill: island
            keys: ["system.timers.showSeconds", "system.timers.showStopwatch", "system.timers.notchStyle"]
            cornerRadius: island.radius
        }

        // The scene in the free space: the dial on the left, the two
        // moments on the right.
        Item {
            id: scene
            x: mini.freeRect.x + mini.freeRect.w * 0.08
            y: mini.freeRect.y + (island.atBottom ? stage.u * 0.6 : island.height + stage.u * 0.4)
            width: mini.freeRect.w * 0.84
            height: mini.freeRect.h - (island.atBottom ? island.height + stage.u * 1.4 : island.height + stage.u * 1.2)

            // The Pomodoro dial: focus and break as one circle.
            Item {
                id: dial
                objectName: "pomodoroDial"
                readonly property real d: Math.min(scene.height, scene.width * 0.42)
                width: d
                height: d
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round(scene.width * 0.24 - d / 2)

                Ring {
                    anchors.fill: parent
                    thickness: Math.max(4, Math.round(stage.u * 0.45))
                    value: stage.work / (stage.work + stage.rest)
                    color: Type.accent
                    trackColor: Qt.alpha(Colors.tertiary, 0.75)
                    Behavior on value {
                        enabled: Motion.glide.duration > 0
                        NumberAnimation {
                            duration: Motion.glide.duration
                            easing.type: Motion.glide.easing
                        }
                    }
                }
                // the dial's face (beside the ring: its centre item takes
                // the size of its children)
                Mark {
                    anchors.fill: parent
                    anchors.margins: Math.round(stage.u * 0.9)
                    color: Qt.alpha(Colors.surfaceContainerLowest, 0.55)
                }
                Column {
                    anchors.centerIn: parent
                    spacing: Math.round(stage.u * 0.1)
                    KitText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        role: "display"
                        tabular: true
                        font.pixelSize: Math.round(dial.d * 0.2)
                        font.weight: Font.Light
                        text: TimerFormat.label(stage.work * 1000, true)
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Math.round(stage.u * 0.25)
                        Mark {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.round(stage.u * 0.4)
                            height: width
                            color: Type.accent
                        }
                        KitText {
                            role: "caption"
                            font.pixelSize: Math.round(stage.u * 0.55)
                            color: Type.text
                            text: I18n.t("timers.phase.work")
                        }
                        Mark {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.round(stage.u * 0.4)
                            height: width
                            color: Colors.tertiary
                        }
                        KitText {
                            role: "caption"
                            font.pixelSize: Math.round(stage.u * 0.55)
                            color: Type.text
                            text: I18n.t("prefs.timers.stage.break").replace("%1", Math.round(stage.rest / 60))
                        }
                    }
                }
                // the next phase starts on its own: a loop at the top
                Mark {
                    visible: stage.autoStart
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -height / 2 + Math.round(stage.u * 0.22)
                    width: Math.round(stage.u * 1.3)
                    height: width
                    color: Colors.surfaceContainerLowest
                    border.width: Space.hairline
                    border.color: Type.accent
                    Icon {
                        anchors.centerIn: parent
                        icon: Icons.repeat
                        size: Math.round(stage.u * 0.7)
                        tone: "accent"
                    }
                }
                StageSpot {
                    keys: ["system.pomodoro"]
                    cornerRadius: dial.d / 2
                }
            }

            // When time is up, and focus mode.
            Column {
                id: moments
                x: Math.round(scene.width * 0.5)
                width: scene.width - x
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(stage.u * 0.6)

                // the alarm: pulsing, ringing, with its panel
                Mark {
                    id: alarm
                    objectName: "timersAlarm"
                    width: moments.width
                    height: Math.round(stage.u * (stage.panel ? 4.2 : 2.6))
                    radius: Look.radius("box", Math.min(height, stage.u * 3))
                    color: stage.surface
                    border.width: Space.hairline
                    border.color: Qt.alpha(Colors.outlineVariant, 0.7)
                    Behavior on height {
                        enabled: Motion.glide.duration > 0
                        NumberAnimation {
                            duration: Motion.glide.duration
                            easing.type: Motion.glide.easing
                        }
                    }

                    Mark {
                        id: bellDot
                        x: Math.round(stage.u * 0.7)
                        y: Math.round(stage.u * 0.6)
                        width: Math.round(stage.u * 1.4)
                        height: width
                        color: Qt.alpha(Colors.error, 0.18)
                        // the pulse: a halo around it while it rings
                        Mark {
                            visible: stage.pulse
                            anchors.centerIn: parent
                            width: parent.width + Math.round(stage.u * 0.6)
                            height: width
                            color: "transparent"
                            border.width: Math.max(2, Math.round(stage.u * 0.1))
                            border.color: Qt.alpha(Colors.error, 0.45)
                        }
                        Icon {
                            anchors.centerIn: parent
                            icon: Icons.alarm
                            size: Math.round(stage.u * 0.75)
                            color: Type.danger
                        }
                    }
                    Column {
                        anchors.left: bellDot.right
                        anchors.leftMargin: Math.round(stage.u * 0.6)
                        anchors.right: speaker.left
                        anchors.rightMargin: Space.xs
                        anchors.verticalCenter: bellDot.verticalCenter
                        KitText {
                            width: parent.width
                            role: "body"
                            font.pixelSize: Math.round(stage.u * 0.62)
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            text: I18n.t("activities.pomodoro_done")
                        }
                        KitText {
                            width: parent.width
                            role: "caption"
                            font.pixelSize: Math.round(stage.u * 0.5)
                            elide: Text.ElideRight
                            text: I18n.t("timers.pomodoro")
                        }
                    }
                    Icon {
                        id: speaker
                        anchors.right: parent.right
                        anchors.rightMargin: Math.round(stage.u * 0.7)
                        anchors.verticalCenter: bellDot.verticalCenter
                        icon: stage.sound ? Icons.speakerHigh : Icons.speakerSlash
                        size: Math.round(stage.u * 0.75)
                        tone: stage.sound ? "accent" : "muted"
                    }
                    // the panel's buttons
                    Row {
                        visible: stage.panel
                        anchors.right: parent.right
                        anchors.rightMargin: Math.round(stage.u * 0.6)
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Math.round(stage.u * 0.5)
                        spacing: Math.round(stage.u * 0.3)
                        Button {
                            text: I18n.t("timers.action.snooze")
                        }
                        Button {
                            text: I18n.t("timers.action.stop")
                            primary: true
                        }
                    }
                }
                // focus mode
                Mark {
                    id: focus
                    objectName: "timersFocus"
                    width: moments.width
                    height: Math.round(stage.u * 2.6)
                    radius: alarm.radius
                    color: stage.surface
                    border.width: Space.hairline
                    border.color: Qt.alpha(Colors.outlineVariant, 0.7)
                    Icon {
                        id: brain
                        x: Math.round(stage.u * 0.75)
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Icons.brain
                        size: Math.round(stage.u * 0.95)
                        tone: "accent"
                    }
                    KitText {
                        anchors.left: brain.right
                        anchors.leftMargin: Math.round(stage.u * 0.55)
                        anchors.right: focusIcons.left
                        anchors.verticalCenter: parent.verticalCenter
                        role: "body"
                        font.pixelSize: Math.round(stage.u * 0.62)
                        elide: Text.ElideRight
                        text: I18n.t("prefs.timers.stage.focus").replace("%1", stage.focusMin)
                    }
                    Row {
                        id: focusIcons
                        anchors.right: parent.right
                        anchors.rightMargin: Math.round(stage.u * 0.7)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.round(stage.u * 0.4)
                        Icon {
                            icon: stage.focusDnd ? Icons.bellSlash : Icons.bell
                            size: Math.round(stage.u * 0.75)
                            tone: stage.focusDnd ? "accent" : "muted"
                        }
                        // the bell's unread badge, gone in focus mode
                        Item {
                            width: Math.round(stage.u * 0.9)
                            height: width
                            Icon {
                                anchors.centerIn: parent
                                icon: Icons.bell
                                size: Math.round(stage.u * 0.75)
                                tone: "muted"
                            }
                            Mark {
                                visible: !stage.focusBadges
                                anchors.right: parent.right
                                anchors.top: parent.top
                                width: Math.round(stage.u * 0.4)
                                height: width
                                color: Type.danger
                            }
                        }
                    }
                }
            }
            StageSpot {
                x: moments.x
                y: moments.y + alarm.y
                width: alarm.width
                height: alarm.height
                keys: ["system.timers.pulseOnFinish", "system.timers.sound", "system.timers.alarmPanel", "system.timers.alarm", "system.timers.phaseSound"]
                cornerRadius: alarm.radius
            }
            StageSpot {
                x: moments.x
                y: moments.y + focus.y
                width: focus.width
                height: focus.height
                keys: ["system.focus"]
                cornerRadius: focus.radius
            }
        }
    }

    // A small button of the alarm panel.
    component Button: Mark {
        id: button
        property string text: ""
        property bool primary: false
        width: buttonText.implicitWidth + stage.u * 0.9
        height: Math.round(stage.u * 1.1)
        radius: Look.radius("button", height)
        color: button.primary ? Type.accent : Qt.alpha(Type.text, 0.08)
        KitText {
            id: buttonText
            anchors.centerIn: parent
            role: "caption"
            font.pixelSize: Math.round(stage.u * 0.5)
            font.weight: Font.Medium
            color: button.primary ? Type.accentInk : Type.text
            text: button.text
        }
    }
}
