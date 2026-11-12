pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "IdleSteps.js" as Steps

// What happens while you are away, as ONE timeline: the four idle steps
// (dim the screen, lock, screen off, sleep) are knobs on a time track (log
// scale, 15 s to 2 h, "never" at the end). Dragging a knob shows the time
// it lands on and writes the idle listeners once, on release, as one undo
// step (system.idle.listeners; other listeners are kept). A knob stays
// between its neighbours, so the order dim -> lock -> off -> sleep holds.
Item {
    id: root
    objectName: "idleTimeline"

    property var entry
    property real fillHeight: 0
    readonly property var listeners: SettingsStore.get("system.idle.listeners") || []
    readonly property var saved: Steps.read(root.listeners)
    // a knob being dragged and the time it shows (null = never)
    property string dragging: ""
    property var dragValue: null
    readonly property var steps: {
        const s = Object.assign({}, root.saved);
        if (root.dragging !== "")
            s[root.dragging] = root.dragValue;
        return s;
    }
    readonly property var meta: ({
            "dim": {
                "icon": Icons.sunDim,
                "label": "prefs.power.step.dim"
            },
            "lock": {
                "icon": Icons.lock,
                "label": "prefs.power.step.lock"
            },
            "off": {
                "icon": Icons.monitor,
                "label": "prefs.power.step.off"
            },
            "sleep": {
                "icon": Icons.moon,
                "label": "prefs.power.step.sleep"
            }
        })
    readonly property var ids: Steps.STEPS.map(s => s.id)
    readonly property real knob: Space.controlXS
    // knob centres on the track, pushed apart where times nearly meet
    readonly property var centres: Steps.spread(root.ids.map(id => track.x + Steps.toPos(root.steps[id]) * track.width), root.knob + Space.xs, track.x, track.x + track.width)

    function commit() {
        const id = root.dragging, v = root.dragValue;
        root.dragging = "";
        if (v === root.saved[id])
            return;
        SettingsStore.transaction("prefs.undo.idle_changed", () => SettingsStore.set("system.idle.listeners", Steps.withStep(root.listeners, id, v)));
    }

    implicitHeight: root.fillHeight > 0 ? root.fillHeight : Space.controlL * 2
    implicitWidth: Space.controlXL * 4

    // the four steps, each its icon, name and time (the knob's legend)
    Row {
        id: legend
        width: root.width
        Repeater {
            model: root.ids
            delegate: Row {
                id: entry
                required property string modelData
                readonly property bool active: root.dragging === modelData
                readonly property bool on: root.steps[modelData] !== null
                width: legend.width / root.ids.length
                spacing: Space.s
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.meta[entry.modelData].icon
                    role: "body"
                    tone: entry.on ? "accent" : "muted"
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    KitText {
                        role: "caption"
                        color: Type.secondary
                        text: I18n.t(root.meta[entry.modelData].label)
                    }
                    KitText {
                        objectName: "idleTime:" + entry.modelData
                        role: "body"
                        font.weight: entry.active ? Type.weight("title") : Type.weight("body")
                        color: entry.active ? Type.accent : (entry.on ? Type.text : Type.muted)
                        text: Steps.label(root.steps[entry.modelData], k => I18n.t(k))
                    }
                }
            }
        }
    }

    // the track: time (filled up to the last step that is on), then never
    Item {
        id: track
        x: root.knob / 2
        width: root.width - root.knob
        y: Math.round(root.height - Space.xl - Space.s - root.knob / 2)
        height: Space.xs

        Mark {
            width: parent.width * Steps.TIME_SPAN
            height: parent.height
            color: Type.track
        }
        Mark {
            readonly property var on: root.ids.filter(id => root.steps[id] !== null)
            width: on.length > 0 ? Steps.toPos(root.steps[on[on.length - 1]]) * parent.width : 0
            height: parent.height
            color: Qt.alpha(Type.accent, 0.55)
        }
        DashedFrame {
            x: parent.width * Steps.TIME_SPAN + Space.xs
            width: parent.width * (1 - Steps.TIME_SPAN) - Space.xs
            y: -Space.s
            height: parent.height + Space.s * 2
            radius: height / 2
            fill: "transparent"
        }

        // a few times under the track
        Repeater {
            model: [60, 300, 900, 3600]
            delegate: KitText {
                required property int modelData
                x: Steps.toPos(modelData) * track.width - implicitWidth / 2
                y: root.knob / 2 + Space.xs
                role: "caption"
                color: Type.muted
                text: Steps.label(modelData, k => I18n.t(k))
            }
        }
        KitText {
            x: track.width * (Steps.TIME_SPAN + 1) / 2 - implicitWidth / 2
            y: root.knob / 2 + Space.xs
            role: "caption"
            color: Type.muted
            text: I18n.t("prefs.power.never")
        }
    }

    Repeater {
        model: root.ids
        delegate: Item {
            id: step
            required property string modelData
            required property int index
            readonly property var value: root.steps[modelData]
            readonly property bool on: step.value !== null
            readonly property bool active: root.dragging === modelData || knobArea.containsMouse
            objectName: "idleStep:" + modelData
            x: root.centres[index] - width / 2
            y: track.y + track.height / 2 - height / 2
            width: root.knob
            height: root.knob
            z: step.active ? 2 : 1

            Mark {
                anchors.fill: parent
                color: step.on ? (step.active ? Type.accent : Look.raisedFill(true)) : Look.raisedFill(false)
                border.width: step.on ? Space.stroke - 1 : Space.hairline
                border.color: step.on ? Type.accent : Type.hairline
                Icon {
                    anchors.centerIn: parent
                    icon: root.meta[step.modelData].icon
                    role: "caption"
                    tone: step.active ? "accentInk" : (step.on ? "text" : "muted")
                }
            }

            // the time over the knob while it is dragged or hovered
            Mark {
                visible: step.active
                anchors.horizontalCenter: parent.horizontalCenter
                y: -height - Space.xs
                width: bubble.implicitWidth + Space.m
                height: bubble.implicitHeight + Space.xs
                color: Look.raisedFill(true)
                border.width: Space.hairline
                border.color: Type.hairline
                KitText {
                    id: bubble
                    anchors.centerIn: parent
                    role: "caption"
                    color: Type.text
                    text: Steps.label(step.value, k => I18n.t(k))
                }
            }

            MouseArea {
                id: knobArea
                objectName: "idleKnob:" + step.modelData
                anchors.fill: parent
                anchors.margins: -Space.xs
                hoverEnabled: true
                preventStealing: true
                cursorShape: Qt.SizeHorCursor
                onPressed: {
                    root.dragValue = step.value;
                    root.dragging = step.modelData;
                }
                onPositionChanged: mouse => {
                    if (root.dragging !== step.modelData)
                        return;
                    const p = mapToItem(track, mouse.x, mouse.y);
                    root.dragValue = Steps.clampTo(root.saved, step.modelData, Steps.fromPos(p.x / track.width));
                }
                onReleased: root.commit()
                onCanceled: root.dragging = ""
            }
        }
    }
}
