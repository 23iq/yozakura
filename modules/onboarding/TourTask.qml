pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../components/kit/ProgressMotion.js" as ProgressMotion
import "../keybinds/KeyNames.js" as KeyNames

// One keybind-tour task as a kit ListRow: a status disc (the task's icon,
// a check once done), what to press (the real bound keys as KeyHints), and
// Show me / Skip while it is the active task (the row is `selected`). The
// active task's disc breathes; the check mark pops in when it completes.
ListRow {
    id: root

    property var task: ({})
    property var keys: null
    // "" (pending) | "done" | "skipped"
    property string status: ""
    property bool active: false

    signal skipRequested
    signal tryRequested

    implicitHeight: Space.controlL
    selected: root.active
    opacity: root.status === "skipped" ? 0.55 : 1
    title: root.task.title ? I18n.t(root.task.title) : ""
    subtitle: root.status === "done" ? I18n.t("onboarding.tour.done") : (root.task.hint ? I18n.t(root.task.hint) : "")

    leading: disc
    trailing: end

    Component {
        id: disc
        // status disc (an indicator, not a control: a plain Rectangle)
        Rectangle {
            readonly property bool done: root.status === "done"
            implicitWidth: Space.controlM
            implicitHeight: Space.controlM
            radius: width / 2
            color: done ? Type.accent : Type.placeholder
            Behavior on color {
                enabled: Motion.enter.duration > 0
                ColorAnimation {
                    duration: Motion.enter.duration
                }
            }

            // the waiting task breathes: a ring that grows and fades
            Rectangle {
                id: pulse
                readonly property int cycle: ProgressMotion.cycle(Motion.emphasis.duration)
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: Space.hairline * 2
                border.color: Type.accent
                visible: root.active && root.status === "" && pulse.cycle > 0
                SequentialAnimation on scale {
                    running: pulse.visible
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 1
                        to: 1.45
                        duration: pulse.cycle
                        easing.type: Easing.OutCubic
                    }
                    PauseAnimation {
                        duration: Motion.glide.duration
                    }
                }
                SequentialAnimation on opacity {
                    running: pulse.visible
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 0.7
                        to: 0
                        duration: pulse.cycle
                        easing.type: Easing.OutCubic
                    }
                    PauseAnimation {
                        duration: Motion.glide.duration
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !parent.done
                text: root.status === "skipped" ? Icons.arrowElbowDownLeft : (Icons[root.task.icon || ""] ?? "")
                font.family: Icons.font
                font.pixelSize: Type.iconSize("body")
                color: root.active ? Type.accent : Type.secondary
            }
            Text {
                anchors.centerIn: parent
                visible: parent.done
                text: Icons.accept
                font.family: Icons.font
                font.pixelSize: Type.iconSize("title")
                color: Type.accentInk
                scale: visible ? 1 : 0.2
                Behavior on scale {
                    enabled: Motion.spring.duration > 0
                    NumberAnimation {
                        duration: Motion.spring.duration
                        easing.type: Motion.spring.easing
                        easing.overshoot: Motion.spring.overshoot
                    }
                }
            }
        }
    }

    Component {
        id: end
        Row {
            spacing: Space.m

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.xs
                opacity: root.status === "" ? 1 : 0.5
                Accessible.role: Accessible.StaticText
                Accessible.name: root.keys ? KeyNames.comboText(root.keys.modifiers, root.keys.key) : ""

                Repeater {
                    model: root.keys && root.keys.key !== "" ? KeyNames.hints(root.keys.modifiers, root.keys.key) : []
                    delegate: KeyHint {
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.text
                        icon: modelData.icon !== "" ? (Icons[modelData.icon] ?? "") : ""
                    }
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.keys || root.keys.key === ""
                    role: "caption"
                    font.italic: true
                    text: I18n.t("onboarding.tour.unbound")
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.xs
                visible: root.active && root.status === ""
                FocusChip {
                    objectName: "tourShow"
                    text: I18n.t("onboarding.tour.show")
                    onClicked: root.tryRequested()
                }
                FocusChip {
                    objectName: "tourSkip"
                    text: I18n.t("onboarding.skip")
                    onClicked: root.skipRequested()
                }
            }
        }
    }
}
