import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "../settings/Ui.js" as Ui

// One keybind-tour task: what to press (the real bound keys as keycaps),
// its state (waiting / done / skipped) and Skip / "Show me" buttons while
// it is the active task. The check mark pops in when it completes.
Item {
    id: root

    property var task: ({})
    property var keys: null
    // "" (pending) | "done" | "skipped"
    property string status: ""
    property bool active: false

    signal skipRequested
    signal tryRequested

    implicitHeight: Math.round(Styling.fontSize(0) * 5.2)

    Rectangle {
        anchors.fill: parent
        radius: Styling.radius(4)
        color: root.active ? Ui.alpha(Colors.primary, 0.12) : Ui.alpha(Colors.overBackground, 0.035)
        border.width: root.active ? 1 : 0
        border.color: Ui.alpha(Colors.primary, 0.6)
        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Motion.enter.duration
            }
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 14

        // status disc: icon -> check
        Item {
            id: disc
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(Styling.fontSize(0) * 2.6)
            height: width

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.status === "done" ? Colors.primary : Ui.alpha(Colors.primary, root.active ? 0.2 : 0.1)
                Behavior on color {
                    enabled: Config.animDuration > 0
                    ColorAnimation {
                        duration: Motion.enter.duration
                    }
                }
            }
            // waiting pulse
            Rectangle {
                id: pulse
                anchors.centerIn: parent
                width: parent.width
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: Colors.primary
                visible: root.active && root.status === "" && Config.animDuration > 0
                SequentialAnimation on scale {
                    running: pulse.visible
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 1
                        to: 1.45
                        duration: 1400
                        easing.type: Easing.OutCubic
                    }
                    PauseAnimation {
                        duration: 200
                    }
                }
                SequentialAnimation on opacity {
                    running: pulse.visible
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 0.7
                        to: 0
                        duration: 1400
                        easing.type: Easing.OutCubic
                    }
                    PauseAnimation {
                        duration: 200
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: root.status !== "done"
                text: root.status === "skipped" ? Icons.arrowElbowDownLeft : (Icons[root.task.icon || ""] ?? "")
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(2)
                color: root.status === "skipped" ? Colors.outline : Colors.primary
            }
            Text {
                id: check
                anchors.centerIn: parent
                visible: root.status === "done"
                text: Icons.accept
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(3)
                color: Colors.overPrimary
                scale: visible ? 1 : 0.2
                Behavior on scale {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration * 1.5
                        easing.type: Motion.morph.easing
                        easing.overshoot: 3
                    }
                }
            }
        }

        Column {
            id: texts
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - disc.width - combo.width - buttons.width - parent.spacing * 3
            spacing: 3
            Text {
                width: parent.width
                text: root.task.title ? I18n.t(root.task.title) : ""
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                font.weight: Font.DemiBold
                font.strikeout: root.status === "skipped"
                color: root.status === "skipped" ? Colors.outline : Colors.overBackground
            }
            Text {
                width: parent.width
                text: root.status === "done" ? I18n.t("onboarding.tour.done") : (root.task.hint ? I18n.t(root.task.hint) : "")
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: root.status === "done" ? Colors.primary : Colors.overSurfaceVariant
            }
        }

        KeyCombo {
            id: combo
            anchors.verticalCenter: parent.verticalCenter
            modifiers: root.keys ? root.keys.modifiers : []
            key: root.keys ? root.keys.key : ""
            sizeOffset: root.active ? 2 : 0
            placeholder: I18n.t("onboarding.tour.unbound")
            opacity: root.status === "" ? 1 : 0.5
        }

        Row {
            id: buttons
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            visible: root.active && root.status === ""
            width: visible ? implicitWidth : 0
            NavButton {
                kind: "ghost"
                text: I18n.t("onboarding.tour.show")
                onClicked: root.tryRequested()
            }
            NavButton {
                kind: "ghost"
                text: I18n.t("onboarding.skip")
                onClicked: root.skipRequested()
            }
        }
    }
}
