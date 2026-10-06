pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.shell
import "../Ui.js" as Ui
import "LayoutSketch.js" as LayoutSketch
import "PartMeta.js" as PartMeta
import "../../shell/LayoutModel.js" as LayoutModel

// The layout builder's live screen: the Layout preview (where views open)
// with the bar, notch and dock as draggable chips stacked on their edges,
// and a shelf of hidden parts under it. Dropping a chip on an edge moves
// (and shows) the part, on the shelf hides it; `edit` carries the change.
LayoutPreview {
    id: root

    property string selectedPart: "bar"
    signal edit(string part, string field, var value)
    signal select(string part)

    hiddenIds: ["bar", "dock", "notch"]
    itemOpacity: 0.3
    stageHeight: 380
    bottomReserve: root.shelfH + 14
    showTag: false

    readonly property var layout: ShellLayout.layout
    readonly property real sx: root.screen.x
    readonly property real sy: root.screen.y
    readonly property real sw: root.screen.width
    readonly property real sh: root.screen.height
    readonly property real thick: Math.max(16, Math.round(root.sh * 0.075))
    readonly property int gap: 4
    readonly property int inset: 6
    readonly property real shelfH: 44
    readonly property var placed: {
        const out = {};
        const rects = LayoutSketch.partRects(root.layout, ShellLayout.stacking, {
            "w": root.sw,
            "h": root.sh,
            "thick": root.thick,
            "gap": root.gap,
            "inset": root.inset
        });
        for (const r of rects)
            out[r.id] = r;
        return out;
    }
    readonly property var hiddenParts: PartMeta.ORDER.filter(p => !root.layout[p].enabled)
    readonly property rect shelf: Qt.rect(root.sx, root.sy + root.sh + 10, root.sw, root.shelfH)

    // Drag state: the part in hand and where it would land ("" | edge | "off")
    property string dragPart: ""
    property string dragTarget: ""
    readonly property bool dropValid: dragTarget === "off" || LayoutModel.canDrop(dragPart, dragTarget)

    function rectOf(part) {
        const r = root.placed[part];
        if (r)
            return {
                "x": root.sx + r.x,
                "y": root.sy + r.y,
                "w": r.w,
                "h": r.h,
                "vertical": r.vertical
            };
        const i = root.hiddenParts.indexOf(part);
        const w = Math.min(120, (root.shelf.width - 96) / 3);
        return {
            "x": root.shelf.x + 80 + i * (w + 8),
            "y": root.shelf.y + (root.shelfH - root.thick) / 2,
            "w": w,
            "h": root.thick,
            "vertical": false
        };
    }

    function targetAt(cx, cy) {
        if (cy >= root.shelf.y - 4)
            return "off";
        return LayoutSketch.nearestEdge(cx - root.sx, cy - root.sy, root.sw, root.sh);
    }

    // Icon of a re-homed content id
    function contentIcon(c) {
        return ({
                "activities": "lightning",
                "clock": "clock",
                "tray": "dotsNine"
            })[c] || "";
    }

    function badgesOf(part) {
        if (part === "notch")
            return ShellLayout.notchSegments.map(c => root.contentIcon(c));
        if (part === "bar" && ShellLayout.homeOf("activities") === "bar" && ShellLayout.cornerContent.indexOf("activities") === -1)
            return [root.contentIcon("activities")];
        return [];
    }

    function drop(part, target) {
        if (target === "" || !root.dropValid)
            return;
        if (target === "off") {
            if (root.layout[part].enabled)
                root.edit(part, "enabled", false);
            return;
        }
        if (!root.layout[part].enabled)
            root.edit(part, "enabled", true);
        if (root.layout[part].edge !== target)
            root.edit(part, "edge", target);
    }

    // Drop bands along the screen edges while a chip is in hand
    Repeater {
        model: ["top", "bottom", "left", "right"]
        Rectangle {
            id: band
            required property string modelData
            readonly property bool vertical: modelData === "left" || modelData === "right"
            readonly property bool hot: root.dragTarget === modelData
            readonly property real t: root.thick + 2 * root.inset
            x: root.sx + (modelData === "right" ? root.sw - t : 0)
            y: root.sy + (modelData === "bottom" ? root.sh - t : 0)
            width: vertical ? t : root.sw
            height: vertical ? root.sh : t
            radius: Math.min(8, t / 2)
            color: !hot ? Ui.alpha(Colors.outlineVariant, 0.12) : root.dropValid ? Ui.alpha(Colors.primary, 0.3) : Ui.alpha(Colors.error, 0.3)
            opacity: root.dragPart !== "" ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.enter.duration
                }
            }
        }
    }

    // Where re-homed content lands when its parts are off
    Rectangle {
        objectName: "screenMockCornerPill"
        readonly property string corner: EdgeService.freeCorner(root.refScreen, "auto")
        readonly property real reserveX: root.inset + (ShellLayout.stacking[corner.indexOf("right") !== -1 ? "right" : "left"] || []).length * (root.thick + root.gap)
        readonly property real reserveY: root.inset + (ShellLayout.stacking[corner.indexOf("bottom") === 0 ? "bottom" : "top"] || []).length * (root.thick + root.gap)
        visible: ShellLayout.cornerContent.length > 0
        width: pillRow.implicitWidth + 14
        height: Math.max(16, root.thick * 0.8)
        radius: height / 2
        x: corner.indexOf("right") !== -1 ? root.sx + root.sw - width - reserveX - 4 : root.sx + reserveX + 4
        y: corner.indexOf("bottom") === 0 ? root.sy + root.sh - height - reserveY - 4 : root.sy + reserveY + 4
        color: Ui.alpha(Colors.surfaceContainerHighest, 0.95)
        border.width: 1
        border.color: Ui.alpha(Colors.primary, 0.6)
        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 4
            Repeater {
                model: ShellLayout.cornerContent
                Text {
                    required property string modelData
                    text: Icons[root.contentIcon(modelData)] || ""
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(-3)
                    color: Colors.overBackground
                }
            }
        }
    }

    // Shelf of hidden parts
    Rectangle {
        objectName: "screenMockShelf"
        x: root.shelf.x
        y: root.shelf.y
        width: root.shelf.width
        height: root.shelf.height
        radius: Math.min(Styling.radius(-2), height / 2)
        color: root.dragTarget === "off" ? Ui.alpha(Colors.primary, 0.16) : Ui.alpha(Colors.surfaceContainerHigh, 0.6)
        border.width: 1
        border.color: root.dragTarget === "off" ? Colors.primary : Ui.alpha(Colors.outlineVariant, 0.6)
        Behavior on color {
            ColorAnimation {
                duration: Motion.enter.duration
            }
        }
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text {
                text: Icons.eye
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overSurfaceVariant
            }
            Text {
                text: I18n.t("prefs.layout.shelf")
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.DemiBold
                color: Colors.overSurfaceVariant
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: 80
            width: parent.width - 92
            visible: root.hiddenParts.length === 0
            text: I18n.t("prefs.layout.shelf.empty")
            elide: Text.ElideRight
            font.family: Styling.defaultFont
            font.pixelSize: Styling.fontSize(-3)
            color: Ui.alpha(Colors.overSurfaceVariant, 0.75)
        }
    }

    // The parts
    Repeater {
        model: PartMeta.ORDER
        PartChip {
            id: chip
            required property string modelData
            readonly property var r: root.rectOf(modelData)
            partId: modelData
            rect: r
            vertical: r.vertical
            selected: root.selectedPart === modelData
            dimmed: !root.layout[modelData].enabled && !dragging
            icon: PartMeta.part(modelData).icon
            label: I18n.t(PartMeta.part(modelData).label)
            badges: root.badgesOf(modelData)
            onPicked: part => root.select(part)
            onMoved: (part, cx, cy) => {
                root.dragPart = part;
                root.dragTarget = root.targetAt(cx, cy);
            }
            onReleased: (part, cx, cy) => {
                const target = root.targetAt(cx, cy);
                root.dragTarget = target;
                root.drop(part, target);
                root.dragPart = "";
                root.dragTarget = "";
            }
        }
    }
}
