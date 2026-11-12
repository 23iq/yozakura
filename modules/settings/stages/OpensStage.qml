pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.services
import qs.modules.settings.store
import "../../shell/hosts/HostResolve.js" as HostResolve

// Stage of Bar > Where things open: your whole screen (ScreenMini) with
// everything that opens drawn where it opens now (HostResolve, the same
// rules as the shell): the launcher, dashboard, quick ask, voice and timer
// panels, shortcut sheet, notifications, on-screen display, power menu and
// the overview. Each is a ghost outline with its icon in its corner; the
// one whose row is under the pointer (or that just changed) is drawn solid,
// named and ringed, and glides to its new place. Surfaces that share a
// place share one ghost (their icons side by side), so no label is ever
// drawn over another. At rest the stage shows ONLY small labelled chips
// (icon + name) where each surface opens. Direct manipulation: a chip of a
// surface that can open in several places (launcher, dashboard, quick ask,
// voice and timers, shortcut sheet) is picked (`picked`): it becomes a
// ghost of the surface ringed in the accent, every other place it can open
// in is a dashed drop zone with its name (zones that would overlap are
// dashed chips at their anchor), everything else fades back; a click on a
// zone moves it there (one undo step), the ghost gliding to its place.
Stage {
    id: stage
    objectName: "opensStage"

    stageHeight: Space.px(300)

    // surface id -> {key: the setting that places it, icon, name}
    readonly property var surfaces: ({
            "launcher": {
                "key": "layout.launcher.host",
                "icon": "magnifyingGlass",
                "name": "prefs.dest.launcher"
            },
            "dashboard": {
                "key": "layout.dashboard.host",
                "icon": "widgets",
                "name": "prefs.dest.dashboard"
            },
            "aiquick": {
                "key": "layout.aiquick.host",
                "icon": "sparkle",
                "name": "prefs.layout.aiquick_host"
            },
            "panels": {
                "key": "layout.panels.host",
                "icon": "timer",
                "name": "prefs.layout.panels_host"
            },
            "cheatsheet": {
                "key": "layout.cheatsheet.host",
                "icon": "keyboard",
                "name": "prefs.layout.cheatsheet_host"
            },
            "notifications": {
                "key": "notifications.position",
                "icon": "bell",
                "name": "prefs.dest.notifications"
            },
            "osd": {
                "key": "layout.osd.position",
                "icon": "speakerHigh",
                "name": "prefs.cat.osd"
            },
            "powermenu": {
                "key": "layout.powermenu.style",
                "icon": "power",
                "name": "prefs.cat.menus"
            },
            "overview": {
                "key": "overview.style",
                "icon": "squaresFour",
                "name": "prefs.cat.overview"
            }
        })
    // The surface in focus: the hovered row's, else the last one changed.
    property string active: "launcher"
    // The surface picked to move ("" none): its drop zones show.
    property string picked: ""
    readonly property var movable: ["launcher", "dashboard", "aiquick", "panels", "cheatsheet"]
    // The other places the picked surface can open in: [{value, label, rect}]
    readonly property var zones: {
        const id = stage.picked;
        if (!id)
            return [];
        const key = stage.surfaces[id].key;
        const entry = SettingsStore.entryByKey[key];
        const now = stage.rectOf(id, "").map(v => Math.round(v)).join(",");
        const out = [];
        for (const opt of (entry && entry.options) || []) {
            const lay = Object.assign({}, stage.layout);
            lay[id] = {
                "host": opt.value
            };
            const host = HostResolve.resolve(lay, id, {
                "notchEnabled": stage.notchOn
            });
            const r = stage.rectOf(id, host).map(v => Math.round(v));
            const k = r.join(",");
            if (k === now || out.some(z => z.key === k))
                continue;
            out.push({
                "key": k,
                "value": opt.value,
                "label": opt.label,
                "rect": r
            });
        }
        // a zone that overlaps another (or the ghost) is shown as a chip
        const hit = (a, b) => a[0] < b[0] + b[2] && b[0] < a[0] + a[2] && a[1] < b[1] + b[3] && b[1] < a[1] + a[3];
        const ghost = stage.rectOf(id, "");
        out.forEach(z => z.compact = hit(z.rect, ghost) || out.some(o => o !== z && hit(o.rect, z.rect)));
        return out;
    }
    function moveTo(value) {
        const key = stage.surfaces[stage.picked].key;
        stage.active = stage.picked;
        stage.picked = "";
        SettingsStore.transaction("prefs.undo.surface_moved", () => SettingsStore.set(key, value));
    }
    readonly property var focusKeys: SettingsStore.focusKeys
    function surfaceOf(key) {
        return Object.keys(stage.surfaces).find(id => stage.surfaces[id].key === key) || "";
    }
    onFocusKeysChanged: {
        const hit = stage.focusKeys.map(k => stage.surfaceOf(k)).find(id => id !== "");
        if (hit)
            stage.active = hit;
    }
    Connections {
        target: SettingsStore
        function onValueSet(key) {
            const hit = stage.surfaceOf(key);
            if (hit)
                stage.active = hit;
        }
    }

    readonly property bool notchOn: SettingsStore.get("notch.enabled") !== false
    readonly property var layout: ({
            "launcher": {
                "host": SettingsStore.get("layout.launcher.host")
            },
            "dashboard": {
                "host": SettingsStore.get("layout.dashboard.host")
            },
            "aiquick": {
                "host": SettingsStore.get("layout.aiquick.host")
            },
            "panels": {
                "host": SettingsStore.get("layout.panels.host")
            },
            "cheatsheet": {
                "host": SettingsStore.get("layout.cheatsheet.host")
            },
            "powermenu": {
                "style": SettingsStore.get("layout.powermenu.style")
            }
        })
    readonly property bool leftSheet: SettingsStore.get("layout.sheet.side") === "left"
    readonly property string notifPosition: String(SettingsStore.get("notifications.position") || "auto")
    readonly property string osdPosition: String(SettingsStore.get("layout.osd.position") || "auto")

    // [x, y, w, h] of a surface on the screen miniature (`host`: where it
    // would open, "" = where it opens now).
    function rectOf(id, host) {
        const f = screen.freeRect;
        const isl = screen.islandRect;
        const u = Math.max(1, screen.unit);
        const small = id === "aiquick" || id === "panels";
        if (id === "notifications") {
            const pos = stage.notifPosition;
            const w = f.w * 0.24, h = f.h * 0.2;
            const left = pos.indexOf("left") >= 0, center = pos === "top" || pos === "bottom";
            const bottom = pos.indexOf("bottom") === 0;
            return [center ? f.x + (f.w - w) / 2 : (left ? f.x + u * 0.5 : f.x + f.w - w - u * 0.5), bottom ? f.y + f.h - h - u * 0.5 : f.y + u * 0.5, w, h];
        }
        if (id === "osd") {
            const pos = stage.osdPosition;
            const w = f.w * 0.2, h = u * 1.4;
            if (pos === "left" || pos === "right")
                return [pos === "left" ? f.x + u * 0.5 : f.x + f.w - h - u * 0.5, f.y + (f.h - w) / 2, h, w];
            return [f.x + (f.w - w) / 2, pos === "top" ? f.y + u * 0.5 : f.y + f.h - h - u * 0.8, w, h];
        }
        if (id === "overview")
            return [f.x + f.w * 0.05, f.y + f.h * 0.06, f.w * 0.9, f.h * 0.88];
        const at = host || HostResolve.resolve(stage.layout, id, {
            "notchEnabled": stage.notchOn
        });
        switch (at) {
        case "notch":
            return small ? [isl.x - u, isl.y, isl.w + u * 2, f.h * 0.34] : [isl.x - isl.w * 0.7, isl.y, isl.w * 2.4, f.h * 0.6];
        case "sheet":
            return [stage.leftSheet ? f.x : f.x + f.w * 0.7, f.y, f.w * 0.3, f.h];
        case "card":
            return [f.x + f.w * 0.72, f.y + u * 0.5, f.w * 0.26, f.h * 0.36];
        case "fullscreen":
            return [f.x + u, f.y + u, f.w - u * 2, f.h - u * 2];
        case "radial":
            return [f.x + (f.w - f.h * 0.5) / 2, f.y + f.h * 0.25, f.h * 0.5, f.h * 0.5];
        default:
            return small ? [f.x + f.w * 0.36, f.y + f.h * 0.22, f.w * 0.28, f.h * 0.3] : [f.x + f.w * 0.3, f.y + f.h * 0.16, f.w * 0.4, f.h * 0.5];
        }
    }

    // Ghosts: surfaces grouped by the place they open in.
    readonly property var places: {
        const out = [];
        Object.keys(stage.surfaces).forEach(id => {
            const r = stage.rectOf(id, "").map(v => Math.round(v));
            const key = r.join(",");
            const at = out.find(p => p.key === key);
            if (at)
                at.ids.push(id);
            else
                out.push({
                    "key": key,
                    "rect": r,
                    "ids": [id]
                });
        });
        // the chips of two places never sit on each other: a later row of
        // chips moves down until it is clear (widths estimated from the
        // names), and stays inside the screen
        const u = Math.max(1, screen.unit);
        const chipH = u * 1.3, gap = u * 0.3;
        const taken = [];
        out.forEach(p => {
            const w = p.ids.reduce((sum, id) => sum + u * 1.6 + I18n.t(stage.surfaces[id].name).length * u * 0.42 + gap, 0);
            let ax = Math.max(0, Math.min(p.rect[0] + u * 0.3, screen.width - w - u * 0.3));
            let ay = p.rect[1] + u * 0.3;
            const hit = () => taken.some(t => ax < t[0] + t[2] && t[0] < ax + w && ay < t[1] + t[3] && t[1] < ay + chipH);
            while (hit() && ay < screen.height)
                ay += chipH + gap;
            p.iconX = ax - p.rect[0];
            p.iconY = ay - p.rect[1];
            taken.push([ax, ay, w, chipH]);
        });
        return out;
    }
    readonly property var activeRect: stage.rectOf(stage.picked || stage.active, "")

    ScreenMini {
        id: screen
        anchors.fill: parent
        barOpacity: stage.barOpacity
        cornerRadius: stage.radius
        // no windows: the outlines are the picture
        showWindows: false

        // the ghosts
        Repeater {
            model: stage.places
            delegate: Item {
                id: place
                required property var modelData
                x: place.modelData.rect[0]
                y: place.modelData.rect[1]
                width: place.modelData.rect[2]
                height: place.modelData.rect[3]
                z: 6
                // picked: the others fade back; those under the ghost hide
                readonly property bool underGhost: {
                    if (stage.picked === "" || place.modelData.ids.indexOf(stage.picked) >= 0)
                        return false;
                    const a = stage.activeRect, r = place.modelData.rect;
                    const cx = r[0] + place.modelData.iconX, cy = r[1] + place.modelData.iconY;
                    return cx >= a[0] && cx <= a[0] + a[2] && cy >= a[1] && cy <= a[1] + a[3];
                }
                opacity: place.underGhost ? 0 : (stage.picked !== "" && place.modelData.ids.indexOf(stage.picked) < 0 ? 0.3 : 1)
                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.micro.duration
                    }
                }

                Row {
                    x: place.modelData.iconX
                    y: place.modelData.iconY
                    spacing: Space.xs
                    Repeater {
                        model: place.modelData.ids
                        delegate: Mark {
                            id: chip
                            required property string modelData
                            readonly property bool canMove: stage.movable.indexOf(modelData) >= 0
                            readonly property bool isPicked: stage.picked === modelData
                            objectName: "opensChip:" + modelData
                            width: chipRow.implicitWidth + Space.m
                            height: chipRow.implicitHeight + Space.xs * 1.5
                            radius: height / 2
                            color: chip.isPicked ? Type.accent : Qt.alpha(Colors.surface, chip.canMove && chipArea.containsMouse ? 0.95 : 0.82)
                            border.width: Space.hairline
                            border.color: chip.isPicked ? Type.accent : Qt.alpha(Colors.overBackground, 0.25)
                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: Space.xs
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: Icons[stage.surfaces[chip.modelData].icon] ?? ""
                                    role: "caption"
                                    tone: chip.isPicked ? "accentInk" : "text"
                                }
                                KitText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    role: "caption"
                                    color: chip.isPicked ? Colors.overPrimary : Type.text
                                    text: I18n.t(stage.surfaces[chip.modelData].name)
                                }
                            }
                            MouseArea {
                                id: chipArea
                                anchors.fill: parent
                                enabled: chip.canMove
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    stage.active = chip.modelData;
                                    stage.picked = chip.isPicked ? "" : chip.modelData;
                                }
                            }
                        }
                    }
                }
            }
        }

        // the surface in focus: solid, named, gliding to its place
        StyledRect {
            id: focusBox
            visible: stage.picked !== ""
            z: 3
            x: stage.activeRect[0]
            y: stage.activeRect[1]
            width: stage.activeRect[2]
            height: stage.activeRect[3]
            variant: "popup"
            // a translucent ghost of the surface, not a block
            opacity: 0.6
            enableShadow: true
            radius: Look.radius("small", height)

            Behavior on x {
                NumberAnimation {
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }

            Row {
                x: Space.s
                y: Math.max(0, Math.min(Space.s, (focusBox.height - height) / 2))
                width: parent.width - Space.s * 2
                spacing: Space.xs
                Icon {
                    id: focusIcon
                    icon: Icons[stage.surfaces[stage.active].icon] ?? ""
                    role: "secondary"
                    tone: "accent"
                }
                KitText {
                    visible: focusBox.width > Space.px(96) && focusBox.height > Space.px(22)
                    width: Math.max(0, parent.width - focusIcon.width - parent.spacing)
                    role: "secondary"
                    color: Type.text
                    text: I18n.t(stage.surfaces[stage.active].name)
                    elide: Text.ElideRight
                }
            }
        }
        // the picked surface's other places: drop zones
        Repeater {
            model: stage.zones
            delegate: Item {
                id: zone
                required property var modelData
                readonly property bool compact: zone.modelData.compact === true
                objectName: "opensZone:" + modelData.value
                z: 7
                // compact: a dashed chip at the zone's anchor (its centre)
                x: zone.compact ? zone.modelData.rect[0] + (zone.modelData.rect[2] - width) / 2 : zone.modelData.rect[0]
                y: zone.compact ? zone.modelData.rect[1] + (zone.modelData.rect[3] - height) / 2 : zone.modelData.rect[1]
                width: zone.compact ? zoneLabel.implicitWidth + Space.l : zone.modelData.rect[2]
                height: zone.compact ? zoneLabel.implicitHeight + Space.s : zone.modelData.rect[3]
                DashedFrame {
                    anchors.fill: parent
                    radius: zone.compact ? height / 2 : Look.radius("small", height)
                    fill: Qt.alpha(Type.accent, zoneArea.containsMouse ? 0.3 : (zone.compact ? 0.18 : 0.08))
                }
                KitText {
                    id: zoneLabel
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - Space.s)
                    role: "caption"
                    font.weight: Font.DemiBold
                    color: Type.text
                    elide: Text.ElideRight
                    text: I18n.t(zone.modelData.label)
                }
                MouseArea {
                    id: zoneArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: stage.moveTo(zone.modelData.value)
                }
            }
        }
        // the picked surface's ghost: ringed in the accent
        Mark {
            anchors.fill: focusBox
            anchors.margins: -Space.xs
            z: 4
            visible: focusBox.visible
            radius: focusBox.radius + Space.xs
            color: "transparent"
            border.width: Space.stroke - 1
            border.color: Type.accent
        }
        StageSpot {
            anchors.fill: focusBox
            z: 4
            keys: Object.keys(stage.surfaces).map(id => stage.surfaces[id].key).concat(["layout.sheet.side", "layout.backdrop"])
            cornerRadius: focusBox.radius
        }
    }
}
