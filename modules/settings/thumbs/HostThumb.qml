pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.store
import "../../shell/hosts/HostResolve.js" as HostResolve

// Card picture of where a surface opens (layout.*.host, the entry's
// `surface`): a screen with the bar and the island, and the surface drawn
// at host `value`: dropping from the island, centered (spotlight), a side
// sheet, a small card under the bar or the whole screen. "auto" shows the
// host it picks right now, marked with a small spark.
MiniScreen {
    id: root

    property var entry
    property var value: "auto"
    readonly property string surface: entry && entry.surface ? entry.surface : "launcher"
    readonly property bool notchOn: SettingsStore.get("notch.enabled") !== false
    readonly property string host: String(root.value) === "auto" ? HostResolve.resolve(HostResolve.layoutWith(root.surface, "auto"), root.surface, {
        "notchEnabled": root.notchOn
    }) : String(root.value)
    readonly property bool leftSheet: SettingsStore.get("layout.sheet.side") === "left"
    readonly property real barH: Math.round(root.u * 7)
    // [x, y, w, h] of the surface, in u.
    readonly property var box: ({
            "notch": [27, 0, 46, 27],
            "spotlight": [24, 13, 52, 24],
            "sheet": [root.leftSheet ? 2 : 66, 9, 32, 46],
            "card": [62, 9, 34, 20],
            "fullscreen": [5, 9, 90, 46],
            "radial": [36, 10, 28, 28]
        })[root.host] || [24, 13, 52, 24]

    StyledRect {
        width: parent.width
        height: root.barH
        variant: "barbg"
        backgroundOpacity: root.barOpacity
        enableShadow: false
        radius: 0
    }

    // The surface; from the island it is the island grown down.
    StyledRect {
        id: surfaceBox
        readonly property bool island: root.host === "notch"
        x: root.box[0] * root.u
        y: root.box[1] * root.u
        width: root.box[2] * root.u
        height: Math.min(root.box[3] * root.u, root.height - y - root.u * 2)
        variant: island ? "bg" : "popup"
        enableShadow: false
        radius: Look.radius("small", height)

        Column {
            x: root.u * 3
            y: (surfaceBox.island ? root.barH : 0) + root.u * 3
            width: parent.width - root.u * 6
            spacing: Math.round(root.u * 2)
            Mark {
                width: parent.width
                height: Math.max(2, Math.round(root.u * 3))
                radius: height / 2
                color: Qt.alpha(Colors.primary, 0.55)
            }
            Repeater {
                model: 2
                delegate: Mark {
                    required property int index
                    width: parent.width * (index === 0 ? 0.7 : 0.5)
                    height: Math.max(2, Math.round(root.u * 1.6))
                    color: Qt.alpha(Colors.overBackground, 0.25)
                }
            }
        }
    }

    // The island (hidden while the surface is the island itself).
    Mark {
        visible: root.notchOn && root.host !== "notch"
        width: root.u * 18
        height: Math.round(root.u * 5)
        x: (root.width - width) / 2
        y: Math.round(root.u)
        color: Colors.surfaceContainerLowest
    }

    Icon {
        visible: String(root.value) === "auto"
        x: root.u * 3
        y: root.height - height - root.u * 2
        icon: Icons.magicWand
        role: "caption"
        tone: "accent"
    }
}
