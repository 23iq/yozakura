pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "../controls/ColorRoleModel.js" as ColorModel

// The focused window's border: its width as strokes of growing weight
// (compositor.borderSize) over the palette colours it can take
// (compositor.activeBorderColor). Picking either stops following the
// shell's own border (syncBorderWidth / syncBorderColor) in the same undo
// step. Left / Right change the width.
FocusScope {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property var widths: [0, 1, 2, 3, 5]
    readonly property var roles: ["primary", "secondary", "tertiary", "error", "outline", "overBackground"]
    readonly property bool syncWidth: SettingsStore.get("compositor.syncBorderWidth") === true
    readonly property bool syncColor: SettingsStore.get("compositor.syncBorderColor") === true
    readonly property int size: Number(SettingsStore.get("compositor.borderSize") ?? 2)
    readonly property string role: {
        const stops = ColorModel.toStops(SettingsStore.get("compositor.activeBorderColor"));
        return stops.length > 0 ? ColorModel.roleOf(stops[0]) : "primary";
    }
    readonly property int current: root.syncWidth ? -1 : root.widths.indexOf(root.size)

    function pickWidth(i) {
        const v = root.widths[Math.max(0, Math.min(root.widths.length - 1, i))];
        SettingsStore.transaction("prefs.undo.window_border", () => {
            SettingsStore.set("compositor.syncBorderWidth", false);
            SettingsStore.set("compositor.borderSize", v);
        });
    }
    function pickColor(r) {
        SettingsStore.transaction("prefs.undo.window_border", () => {
            SettingsStore.set("compositor.syncBorderColor", false);
            SettingsStore.set("compositor.activeBorderColor", [r]);
        });
    }

    implicitHeight: root.fillHeight > 0 ? root.fillHeight : Space.controlL * 2
    activeFocusOnTab: true
    Keys.onLeftPressed: root.pickWidth(root.current - 1)
    Keys.onRightPressed: root.pickWidth(root.current + 1)

    Row {
        id: strip
        width: parent.width
        height: parent.height - swatches.height - Space.m
        spacing: Space.s

        Repeater {
            model: root.widths
            delegate: PickTile {
                id: step
                required property int modelData
                required property int index
                objectName: "borderWidth:" + modelData
                width: (strip.width - strip.spacing * (root.widths.length - 1)) / root.widths.length
                height: strip.height
                chosen: index === root.current
                caption: String(modelData)
                onClicked: root.pickWidth(index)

                // a stroke of this width in the border colour (none: a faint dash)
                Mark {
                    anchors.centerIn: parent
                    width: parent.width * 0.8
                    height: Math.max(Space.hairline, step.modelData)
                    radius: 0
                    color: step.modelData > 0 ? swatches.colorOf(root.role) : Type.track
                }
            }
        }
    }

    Row {
        id: swatches
        objectName: "borderColours"
        anchors.bottom: parent.bottom
        spacing: Space.s
        height: Space.controlXS

        function colorOf(r) {
            return Colors[r] !== undefined ? Colors[r] : Type.accent;
        }

        Repeater {
            model: root.roles
            delegate: Mark {
                id: swatch
                required property string modelData
                readonly property bool chosen: !root.syncColor && root.role === modelData
                objectName: "borderColour:" + modelData
                width: Space.controlXS
                height: Space.controlXS
                color: swatches.colorOf(modelData)
                border.width: swatch.chosen ? Space.stroke : Space.hairline
                border.color: swatch.chosen ? Type.text : Type.hairline
                scale: swatchArea.containsMouse ? 1.1 : 1
                Behavior on scale {
                    enabled: Motion.micro.duration > 0
                    NumberAnimation {
                        duration: Motion.micro.duration
                    }
                }
                MouseArea {
                    id: swatchArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pickColor(swatch.modelData)
                }
            }
        }
    }

    FocusRing {
        shown: root.activeFocus
        radius: Look.radius("box", Space.controlL)
    }
}
