pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// The two window gaps as a pair of sliders, each a caption over its line
// (compositor.gapsIn between windows, compositor.gapsOut to the screen
// edges): a drag is applied live and coalesces into one undo step; the
// stage moves the windows as it goes. Hovering a slider lights its gap on
// the stage.
Column {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property var gaps: [
        {
            "key": "compositor.gapsIn",
            "label": "prefs.windows.gaps_in",
            "icon": Icons.columns,
            "to": 50
        },
        {
            "key": "compositor.gapsOut",
            "label": "prefs.windows.gaps_out",
            "icon": Icons.frameCorners,
            "to": 100
        }
    ]

    spacing: Space.m

    Repeater {
        model: root.gaps
        delegate: Column {
            id: gap
            required property var modelData
            readonly property real value: Number(SettingsStore.get(modelData.key) ?? 0)
            objectName: "gap:" + modelData.key
            width: root.width
            spacing: Space.xs

            KitText {
                role: "secondary"
                text: I18n.t(gap.modelData.label)
            }
            LineSlider {
                id: line
                width: parent.width
                from: 0
                to: gap.modelData.to
                step: 1
                value: gap.value
                icon: gap.modelData.icon
                showValue: true
                valueText: Math.round(gap.value) + " px"
                onMoved: v => {
                    SettingsStore.set(gap.modelData.key, Math.round(v));
                    line.value = Qt.binding(() => gap.value);
                }
                onHoveredChanged: {
                    if (line.hovered)
                        SettingsStore.point(line, [gap.modelData.key]);
                    else
                        SettingsStore.unpoint(line);
                }
            }
        }
    }
}
