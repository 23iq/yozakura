pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.notch
import qs.modules.widgets.defaultview
// EdgeService (a singleton of this directory) through the module: tooling
// resolves the implicit directory import without its qmldir
import qs.modules.shell
import "../notch/NotchShape.js" as NotchShape
import "../notch/styles/NotchStyles.js" as NotchStyles
import "../components/preview/Preview.js" as Preview

// The resting island of a screen as NotchContent shows it, for a settings
// preview (components/preview, modules/settings/live/LiveIsland): the real
// Notch with the real resting view (DefaultView: header, media summary,
// activities, notifications) at its place on the edge (NotchPlacement, the
// edge gap), on an item as large as the screen. It lives in the shell
// layer, beside NotchContent (the live notch's composer): it places the
// notch with EdgeService. Revealed, inert and
// claiming nothing: no visibilities, no registration, no hover logic, no
// panel of its own (`ownsAutoPanels` off), no cava consumer. What it shows
// comes from `preview`: the looks it varies (`notch.style`,
// `notch.position`, `notch.align`) and its samples ("player",
// "notifications", "activities", "levels", "focusedTitle"; a sample left
// out is the session's).
Item {
    id: root

    // a ShellScreen (or {name, width, height})
    required property var screen
    property var preview: null

    readonly property string position: Preview.pick(root.preview, "notch.position", Config.notchPosition ?? "top")
    readonly property string theme: NotchStyles.legacyTheme(Preview.pick(root.preview, "notch.style", Config.notchStyle))
    readonly property bool vertical: NotchShape.vertical(root.position)
    readonly property int frameOffset: Config.bar && Config.bar.frameEnabled ? (Config.bar.frameThickness ?? 6) : 0
    readonly property int edgeGap: NotchShape.edgeGap(root.theme, root.position, root.frameOffset)
    readonly property Item notch: notch
    // the island in this item (its silhouette, the edge gap excluded), as
    // drawn now and where its morph goes (not animated: a frame follows it)
    readonly property rect notchRect: Qt.rect(region.x + notch.x, region.y + notch.y, notch.width, notch.height)
    readonly property rect targetRect: {
        const tw = notch.targetWidth, th = notch.targetHeight;
        const box = {
            "w": tw + (root.vertical ? root.edgeGap : 0),
            "h": th + (root.vertical ? 0 : root.edgeGap)
        };
        const at = NotchShape.viewPos(root.position, box, {
            "w": tw,
            "h": th
        }, root.edgeGap);
        return Qt.rect(target.x + at.x, target.y + at.y, tw, th);
    }

    implicitWidth: root.screen ? root.screen.width : 0
    implicitHeight: root.screen ? root.screen.height : 0
    enabled: false

    // the edge environment with the preview's place of the island
    readonly property var env: {
        const e = EdgeService.envFor(root.screen);
        e.notch = Object.assign({}, e.notch, {
            "pos": root.position,
            "align": Preview.pick(root.preview, "notch.align", e.notch.align),
            "visible": true
        });
        return e;
    }
    NotchPlacement {
        id: placement
        env: root.env
        width: region.width
        height: region.height
    }
    NotchPlacement {
        id: target
        env: root.env
        width: notch.targetWidth + (root.vertical ? root.edgeGap : 0)
        height: notch.targetHeight + (root.vertical ? 0 : root.edgeGap)
    }

    Item {
        id: region
        x: placement.x
        y: placement.y
        width: notch.width + (root.vertical ? root.edgeGap : 0)
        height: notch.height + (root.vertical ? 0 : root.edgeGap)

        Notch {
            id: notch
            readonly property var at: NotchShape.viewPos(root.position, {
                "w": region.width,
                "h": region.height
            }, {
                "w": notch.width,
                "h": notch.height
            }, root.edgeGap)
            x: Math.round(at.x)
            y: Math.round(at.y)
            width: implicitWidth
            height: implicitHeight
            preview: root.preview
            screenName: root.screen ? root.screen.name : ""
            visibilities: null
            defaultViewComponent: Component {
                DefaultView {
                    preview: root.preview
                    screenName: root.screen ? root.screen.name : ""
                    ownsAutoPanels: false
                }
            }
        }
    }
}
