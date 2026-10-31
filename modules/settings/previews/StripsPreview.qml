pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.controls
import qs.modules.notifications.strips

// Under the presentation picker while "strips" is chosen: three sample
// strips hanging from the stage's top edge with the live material, thread
// and palette (the real StripBody, at rest).
PreviewStage {
    id: root

    property var entry
    readonly property bool shown: !!Config.notifications && Config.notifications.presentation === "strips"
    readonly property var options: Config.notifications ? Config.notifications.strips : null
    readonly property bool thread: !root.options || root.options.thread !== false
    readonly property int stripShort: Space.controlM + Space.xs
    readonly property int stripLong: 2 * Space.controlXL

    visible: root.shown
    stageHeight: root.shown ? root.stripLong + Space.xxl + Space.l : 0
    showTag: false

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Space.xl
        spacing: Space.m

        Repeater {
            model: [
                {
                    "key": "music",
                    "app": "Music",
                    "drop": Space.l
                },
                {
                    "key": "calendar",
                    "app": "Calendar",
                    "drop": Space.xl
                },
                {
                    "key": "mail",
                    "app": "Mail",
                    "drop": Space.s
                }
            ]

            Item {
                id: hung
                required property var modelData
                width: root.stripShort
                height: hung.modelData.drop + root.stripLong

                Rectangle {
                    visible: root.thread
                    x: (hung.width - width) / 2
                    width: Space.hairline
                    height: hung.modelData.drop + Space.s
                    color: Type.muted
                }

                StripBody {
                    y: hung.modelData.drop
                    width: root.stripShort
                    height: root.stripLong
                    foldedWidth: root.stripShort
                    foldedHeight: root.stripLong
                    material: root.options ? root.options.material : "plain"
                    seed: hung.modelData.key.length * 7
                    hole: root.thread
                    notification: ({
                            "appName": hung.modelData.app,
                            "summary": I18n.t("prefs.notif.strips.sample." + hung.modelData.key),
                            "urgency": 1
                        })
                }
            }
        }
    }
}
