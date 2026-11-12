pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../../routines/RoutineModel.js" as RoutineModel
import "../../../config/KeybindActions.js" as KeybindActions

// Band of the Routines page (list form): one routine as a "when -> then"
// strip. When: what starts it (a key, the launcher, the Assistant); then:
// its steps in order, the last one ends in a check. Your first routine, or
// the Night template while you have none. The play button runs it now
// (a template is saved as your routine first).
Stage {
    id: band

    readonly property var saved: RoutinesService.routines || []
    readonly property bool sample: band.saved.length === 0
    readonly property var routine: band.sample ? RoutineModel.fromTemplate("night", k => I18n.t(k)) : band.saved[0]
    readonly property var steps: (band.routine && band.routine.steps) || []
    readonly property int shown: Math.min(band.steps.length, 4)
    readonly property real u: Math.max(Space.px(10), Math.min(band.height * 0.1, band.width * 0.016))
    property bool busy: false

    function summary(step) {
        return RoutineModel.stepSummary(step, RoutinesService.tools, key => I18n.has(key) ? I18n.t(key) : "", id => I18n.t(KeybindActions.labelKey(id)));
    }
    function stepIcon(step) {
        return step.kind === "delay" ? Icons.hourglass : (step.kind === "action" ? Icons.keyboard : Icons.lightning);
    }
    function play() {
        if (band.busy)
            return;
        band.busy = true;
        if (band.sample) {
            RoutinesService.save(band.routine, "", () => {
                band.busy = false;
                RoutinesService.refresh();
            });
            return;
        }
        RoutinesService.run(band.routine.id, () => band.busy = false);
    }

    stageHeight: Space.px(170)
    Component.onCompleted: RoutinesService.ensureTools()

    // the wallpaper sits back behind the strip
    Mark {
        anchors.fill: parent
        radius: band.radius
        color: Qt.alpha(Colors.shadow, 0.45)
    }

    Row {
        id: strip
        objectName: "routineStrip"
        anchors.verticalCenter: parent.verticalCenter
        x: Math.round(band.u * 2)
        width: band.width - x * 2
        spacing: Math.round(band.u * 1.2)

        // the routine: its icon and name
        Column {
            id: who
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(band.width * 0.16)
            spacing: Math.round(band.u * 0.5)
            Mark {
                width: Math.round(band.u * 4)
                height: width
                radius: Look.radius("box", height)
                color: Type.accent
                Icon {
                    anchors.centerIn: parent
                    icon: Icons[band.routine.icon] ?? Icons.lightning
                    size: Math.round(band.u * 2)
                    tone: "accentInk"
                }
            }
            KitText {
                width: parent.width
                role: "title"
                elide: Text.ElideRight
                text: band.routine.name || I18n.t("routines.untitled")
            }
            KitText {
                width: parent.width
                visible: band.sample
                role: "caption"
                color: Type.muted
                elide: Text.ElideRight
                text: I18n.t("prefs.routines.band.example")
            }
        }

        // when: the ways it starts
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(band.u * 0.5)
            KitText {
                role: "caption"
                color: Type.muted
                text: I18n.t("prefs.routines.band.when")
            }
            Repeater {
                model: [
                    {
                        "icon": "keyboard",
                        "label": "prefs.routines.band.key"
                    },
                    {
                        "icon": "magnifyingGlass",
                        "label": "prefs.routines.band.launcher"
                    },
                    {
                        "icon": "sparkle",
                        "label": "prefs.dest.assistant"
                    }
                ]
                delegate: Row {
                    id: trigger
                    required property var modelData
                    spacing: Math.round(band.u * 0.4)
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Icons[trigger.modelData.icon] ?? ""
                        role: "caption"
                        tone: "secondary"
                    }
                    KitText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "caption"
                        color: Type.text
                        text: I18n.t(trigger.modelData.label)
                    }
                }
            }
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.arrowRight
            size: Math.round(band.u * 1.6)
            tone: "accent"
        }

        // then: the steps
        Row {
            id: steps
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(band.u * 0.5)
            readonly property real room: strip.width - who.width - play.width - strip.spacing * 4 - Math.round(band.u * 12)
            readonly property real stepW: Math.min(Math.round(band.u * 12), (room - spacing * 2 * band.shown) / Math.max(1, band.shown + (band.steps.length > band.shown ? 0.6 : 0)))
            Repeater {
                model: band.steps.slice(0, band.shown)
                delegate: Row {
                    id: stepItem
                    required property var modelData
                    required property int index
                    spacing: steps.spacing
                    Mark {
                        width: steps.stepW
                        height: Math.round(band.u * 5.6)
                        radius: Look.radius("box", height)
                        color: Qt.alpha(Colors.surfaceContainer, 0.92)
                        border.width: Space.hairline
                        border.color: Qt.alpha(Colors.outlineVariant, 0.7)
                        Icon {
                            x: Math.round(band.u * 0.8)
                            y: Math.round(band.u * 0.8)
                            icon: band.stepIcon(stepItem.modelData)
                            size: Math.round(band.u * 1.3)
                            tone: "accent"
                        }
                        KitText {
                            x: Math.round(band.u * 0.8)
                            width: parent.width - band.u * 1.6
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Math.round(band.u * 0.7)
                            role: "secondary"
                            color: Type.text
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                            text: band.summary(stepItem.modelData)
                        }
                    }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: stepItem.index < band.shown - 1 || band.steps.length > band.shown
                        icon: Icons.caretRight
                        role: "caption"
                        tone: "muted"
                    }
                }
            }
            KitText {
                anchors.verticalCenter: parent.verticalCenter
                visible: band.steps.length > band.shown
                role: "secondary"
                text: "+" + (band.steps.length - band.shown)
            }
            Mark {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(band.u * 2.2)
                height: width
                color: Qt.alpha(Type.accent, 0.18)
                Icon {
                    anchors.centerIn: parent
                    icon: Icons.check
                    size: Math.round(band.u * 1.1)
                    tone: "accent"
                }
            }
        }
    }

    // run it now (a template: keep it as your routine)
    IconButton {
        id: play
        objectName: "routinePlay"
        anchors.right: parent.right
        anchors.rightMargin: Math.round(band.u * 2)
        anchors.verticalCenter: parent.verticalCenter
        size: "l"
        primary: true
        icon: band.sample ? Icons.plus : Icons.play
        tooltip: I18n.t(band.sample ? "prefs.routines.band.keep" : "routines.run")
        enabled: !band.busy
        onClicked: band.play()
    }
}
