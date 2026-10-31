pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.controls
import qs.modules.settings.store
import "../../shell/osd/OsdStyles.js" as OsdStyles

// The chosen OSD style as it draws: the real style component (OsdStyles)
// showing a volume and a brightness level side by side. The bar-inline style
// lives in the bar's controls button, so it is named instead of drawn.
PreviewStage {
    id: root

    property var entry
    readonly property string style: OsdStyles.normalize(SettingsStore.get("layout.osd.style"))
    readonly property bool windowed: root.style !== "bar-inline"
    readonly property var samples: [
        {
            "kind": "volume",
            "value": 0.62
        },
        {
            "kind": "brightness",
            "value": 0.38
        }
    ]

    stageHeight: (root.windowed ? OsdStyles.sizeFor(root.style, false, Metrics.osdW).h : Space.controlM) + Space.xl * 2

    Row {
        visible: root.windowed
        anchors.centerIn: parent
        spacing: Space.l

        Repeater {
            model: root.windowed ? root.samples : []

            Loader {
                id: sample
                required property var modelData
                source: "../../shell/osd/" + OsdStyles.fileFor(root.style)
                onLoaded: {
                    sample.item.kind = sample.modelData.kind;
                    sample.item.value = sample.modelData.value;
                    sample.item.shown = true;
                }
            }
        }
    }

    KitText {
        visible: !root.windowed
        anchors.centerIn: parent
        role: "secondary"
        text: I18n.t("prefs.osd.style.bar_inline")
    }
}
