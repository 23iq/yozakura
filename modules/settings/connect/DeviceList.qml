pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// The list of a connect page's card (Wi-Fi networks, Bluetooth devices,
// audio devices): rows of a glyph, a name, a state line and a trailing
// mark, the picked one washed in the accent; it scrolls inside its card
// with a fade at the foot while more is below. `rows`: [{key, icon, title,
// line, on, trailing, volume}] (icon / trailing: Icons names; volume: a
// level 0..1.5 the row shows as its own volume line, -1 or absent: none).
// `empty`: what an empty list says.
Item {
    id: root

    property var rows: []
    property string current: ""
    property string empty: ""
    property real fillHeight: 0
    // a short list (sound devices, effect presets): the rows grow to share
    // the card's height (up to a roomy tile each) instead of leaving it empty
    property bool stretch: false
    readonly property real baseH: Space.controlM + Space.s
    signal picked(string key)
    // a row's volume line moved (the rows with a `volume`)
    signal volumeMoved(string key, real value)

    implicitHeight: root.fillHeight > 0 ? root.fillHeight : Space.controlL * 3
    clip: true

    KitText {
        anchors.centerIn: parent
        visible: root.rows.length === 0
        role: "secondary"
        text: root.empty
    }

    ListView {
        id: list
        objectName: "deviceList"
        anchors.fill: parent
        model: root.rows
        boundsBehavior: Flickable.StopAtBounds
        spacing: Space.xs
        delegate: Item {
            id: row
            required property var modelData
            readonly property bool chosen: modelData.key === root.current
            readonly property bool hasVolume: (row.modelData.volume ?? -1) >= 0
            objectName: "deviceRow:" + modelData.key
            width: list.width
            readonly property real need: root.baseH + (row.hasVolume ? Space.controlS : 0)
            height: root.stretch && root.rows.length > 0 ? Math.max(row.need, Math.min(row.need * 1.9, (list.height - list.spacing * (root.rows.length - 1)) / root.rows.length)) : row.need
            // the extra height of a stretched row, split around its content
            readonly property real lift: Math.round((row.height - row.need) / 2)

            Mark {
                anchors.fill: parent
                radius: Look.radius("control", height)
                color: row.chosen ? Qt.alpha(Type.accent, 0.16) : (area.containsMouse ? Look.raisedFill(true) : "transparent")
            }
            Icon {
                id: glyph
                x: Space.m
                anchors.verticalCenter: titles.verticalCenter
                icon: Icons[row.modelData.icon] ?? Icons.circle
                role: root.stretch ? "display" : "title"
                tone: row.modelData.on ? "accent" : "secondary"
            }
            Column {
                id: titles
                anchors.left: glyph.right
                anchors.leftMargin: Space.m
                anchors.right: tail.left
                anchors.rightMargin: Space.s
                y: row.lift + Math.round((root.baseH - height) / 2)
                KitText {
                    width: parent.width
                    role: "body"
                    elide: Text.ElideRight
                    font.weight: row.modelData.on ? Type.weight("title") : Type.weight("body")
                    text: row.modelData.title
                }
                KitText {
                    width: parent.width
                    visible: text !== ""
                    role: "caption"
                    color: row.modelData.on ? Type.accent : Type.secondary
                    elide: Text.ElideRight
                    text: row.modelData.line || ""
                }
            }
            Icon {
                id: tail
                anchors.right: parent.right
                anchors.rightMargin: Space.m
                anchors.verticalCenter: titles.verticalCenter
                visible: (row.modelData.trailing || "") !== ""
                icon: Icons[row.modelData.trailing || "circle"] ?? ""
                role: "caption"
                tone: "muted"
            }
            // the device's own volume, under its name
            LineSlider {
                id: level
                objectName: "deviceVolume:" + row.modelData.key
                visible: row.hasVolume
                // over the row's click area (it is the last child)
                z: 1
                anchors.left: titles.left
                anchors.right: parent.right
                anchors.rightMargin: Space.m
                y: row.lift + Space.controlM
                height: Space.controlS
                from: 0
                to: 1.5
                step: 0.05
                value: Math.max(0, row.modelData.volume ?? 0)
                showValue: true
                valueText: Math.round(level.value * 100) + " %"
                onMoved: v => {
                    root.volumeMoved(row.modelData.key, v);
                    level.value = Qt.binding(() => Math.max(0, row.modelData.volume ?? 0));
                }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(row.modelData.key)
            }
        }
    }

    // more below
    Mark {
        visible: list.contentHeight > list.height && list.contentY < list.contentHeight - list.height - 1
        anchors.bottom: parent.bottom
        width: parent.width
        height: Space.l
        radius: 0
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Look.cardFill(false)
            }
        }
    }
}
