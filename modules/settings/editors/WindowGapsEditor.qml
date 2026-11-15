pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// The two window gaps as a pair of slider rows, the label on the left and
// the slider on the card's control column like every slider row
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

    spacing: 0

    // one value column for both: the tracks end on one line
    FontMetrics {
        id: valueMetrics
        font.family: Type.family("secondary")
        font.pixelSize: Type.size("secondary")
    }

    Repeater {
        model: root.gaps
        delegate: RowLayout {
            id: gap
            required property var modelData
            readonly property real value: Number(SettingsStore.get(modelData.key) ?? 0)
            objectName: "gap:" + modelData.key
            width: root.width
            height: Space.rowHeight - Space.xs * 2
            spacing: Space.l

            KitText {
                Layout.fillWidth: true
                role: "body"
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                text: I18n.t(gap.modelData.label)
            }
            LineSlider {
                id: line
                Accessible.role: Accessible.Slider
                Accessible.name: I18n.t(gap.modelData.label)
                Accessible.description: line.valueText
                Layout.preferredWidth: Math.round(root.width * 0.6)
                from: 0
                to: gap.modelData.to
                step: 1
                value: gap.value
                showValue: true
                valueWidth: Math.ceil(valueMetrics.advanceWidth("100 px"))
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
