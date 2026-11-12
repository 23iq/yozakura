pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.services
import qs.modules.settings.store
import "../../shell/hosts/HostResolve.js" as HostResolve

// Stage of Bar > Where things open: your screen with the bar and the
// island, and one surface open where it opens now (HostResolve, the same
// rules as the shell): the one whose row is under the pointer or focus,
// else the launcher. The surface glides to its new place when its host
// changes; its name sits in it so the picture never needs a caption.
Stage {
    id: stage

    stageHeight: Space.px(280)

    // layout.<surface>.host keys -> surface ids (SurfaceRegistry.js)
    readonly property var surfaces: ({
            "layout.launcher.host": "launcher",
            "layout.dashboard.host": "dashboard",
            "layout.aiquick.host": "aiquick",
            "layout.panels.host": "panels",
            "layout.cheatsheet.host": "cheatsheet"
        })
    readonly property var names: ({
            "launcher": "prefs.dest.launcher",
            "dashboard": "prefs.dest.dashboard",
            "aiquick": "prefs.layout.aiquick_host",
            "panels": "prefs.layout.panels_host",
            "cheatsheet": "prefs.layout.cheatsheet_host"
        })
    // The surface shown: the hovered row's, else the last one, else the
    // launcher.
    property string surface: "launcher"
    readonly property var focusKeys: SettingsStore.focusKeys
    onFocusKeysChanged: {
        const hit = stage.focusKeys.map(k => stage.surfaces[k]).find(s => !!s);
        if (hit)
            stage.surface = hit;
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
            }
        })
    readonly property string host: HostResolve.resolve(stage.layout, stage.surface, {
        "notchEnabled": stage.notchOn
    })
    readonly property bool leftSheet: SettingsStore.get("layout.sheet.side") === "left"
    readonly property bool dim: SettingsStore.get("layout.backdrop") !== false && (stage.host === "sheet" || stage.host === "spotlight")
    readonly property real u: stage.width / 100
    readonly property real barH: Math.round(Space.px(30))
    readonly property real islandW: stage.u * 15
    // [x, y, w, h] of the surface (px).
    readonly property var box: {
        const u = stage.u;
        const h = stage.height;
        const small = stage.surface === "aiquick" || stage.surface === "panels";
        switch (stage.host) {
        case "notch":
            return small ? [u * 37, 0, u * 26, h * 0.42] : [u * 28, 0, u * 44, h * 0.66];
        case "sheet":
            return [stage.leftSheet ? u * 1.5 : u * 70.5, stage.barH + u * 1.5, u * 28, h - stage.barH - u * 3];
        case "card":
            return [u * 70, stage.barH + u * 1.5, u * 28, h * 0.42];
        case "fullscreen":
            return [u * 4, stage.barH + u * 2, u * 92, h - stage.barH - u * 4];
        default:
            return small ? [u * 34, h * 0.22, u * 32, h * 0.4] : [u * 25, h * 0.2, u * 50, h * 0.56];
        }
    }

    // The bar.
    StyledRect {
        width: stage.width
        height: stage.barH
        variant: "barbg"
        backgroundOpacity: stage.barOpacity
        enableShadow: false
        radius: 0

        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: Space.m
            spacing: Space.m
            Repeater {
                model: ["launch", "squaresFour", "dotsNine"]
                delegate: Icon {
                    required property string modelData
                    required property int index
                    icon: Icons[modelData] ?? Icons.circle
                    role: "secondary"
                    tone: index === 0 ? "accent" : "text"
                }
            }
        }
        KitText {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Space.m
            role: "secondary"
            text: "21:47"
            tabular: true
        }
    }

    // The screen behind a sheet or spotlight dims (layout.backdrop).
    Mark {
        anchors.fill: parent
        radius: 0
        color: Colors.shadow
        opacity: stage.dim ? 0.32 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }
    }

    // The island (it grows into the surface when the surface opens there).
    Mark {
        visible: stage.notchOn && stage.host !== "notch"
        width: stage.islandW
        height: Math.round(stage.barH * 0.8)
        x: (stage.width - width) / 2
        y: Math.round(stage.barH * 0.1)
        color: Colors.surfaceContainerLowest
    }

    // The surface.
    StyledRect {
        id: surfaceBox
        readonly property bool island: stage.host === "notch"
        x: stage.box[0]
        y: stage.box[1]
        width: stage.box[2]
        height: stage.box[3]
        variant: island ? "bg" : "popup"
        enableShadow: true
        radius: Look.radius("surface", height)

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

        Column {
            x: Space.l
            y: (surfaceBox.island ? stage.barH * 0.6 : 0) + Space.l
            width: parent.width - Space.l * 2
            spacing: Space.m

            KitText {
                width: parent.width
                role: "title"
                text: I18n.t(stage.names[stage.surface] || "")
                elide: Text.ElideRight
            }
            Mark {
                width: parent.width
                height: Space.controlXS
                radius: Look.radius("control", height)
                color: Qt.alpha(Colors.overBackground, 0.08)
            }
            Repeater {
                model: 3
                delegate: Mark {
                    required property int index
                    width: parent.width * (0.82 - index * 0.16)
                    height: Space.s
                    color: Qt.alpha(Colors.overBackground, 0.16)
                }
            }
        }
    }
    StageSpot {
        anchors.fill: surfaceBox
        keys: Object.keys(stage.surfaces).concat(["layout.sheet.side", "layout.backdrop"])
        cornerRadius: surfaceBox.radius
    }
}
