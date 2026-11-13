pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.store
import "../../dock/indicators/IndicatorRegistry.js" as Indicators

// Stage of the dock tab: the dock itself, a strip at a readable scale (a
// little over its real size) as configured: attached to the edge or
// floating, its height, icon size and spacing, the real running-app
// indicator style (modules/dock/indicators, by URL) under the apps that
// run, the pin and overview buttons when on; with magnification on, an
// app swells under the pointer. Not a desktop: where it sits is the Edge
// row's job. A click on it scrolls to the card of what was clicked.
Stage {
    id: stage
    objectName: "dockStage"

    readonly property bool dockOn: SettingsStore.get("dock.enabled") !== false
    readonly property string theme: String(SettingsStore.get("dock.theme") || "default")
    readonly property real zoom: 1.3
    readonly property real iconSize: Math.round(Number(SettingsStore.get("dock.iconSize") || 24) * stage.zoom)
    readonly property real dockHeight: Math.round(Math.max(Number(SettingsStore.get("dock.height") || 48), Number(SettingsStore.get("dock.iconSize") || 24) + 12) * stage.zoom)
    readonly property real spacing: Math.round(Number(SettingsStore.get("dock.spacing") ?? 4) * stage.zoom)
    readonly property bool floating: stage.theme === "floating"
    readonly property bool magnify: SettingsStore.get("dock.magnification") === true
    readonly property real magnifyScale: Number(SettingsStore.get("dock.magnificationScale") || 1.6)
    readonly property string indicatorUrl: Qt.resolvedUrl("../../dock/indicators/" + Indicators.get(String(SettingsStore.get("dock.indicator") || "dot")).url)
    readonly property bool showRunning: SettingsStore.get("dock.showRunningIndicators") !== false
    // sample apps: icon name, a letter while the icon theme has none,
    // windows open (indicator marks), focused
    readonly property var apps: [
        {
            "icon": "firefox",
            "letter": "F",
            "count": 2,
            "focused": true
        },
        {
            "icon": "kitty",
            "letter": "K",
            "count": 1,
            "focused": false
        },
        {
            "icon": "org.gnome.Nautilus",
            "letter": "N",
            "count": 0,
            "focused": false
        },
        {
            "icon": "code",
            "letter": "C",
            "count": 1,
            "focused": false
        },
        {
            "icon": "spotify",
            "letter": "S",
            "count": 0,
            "focused": false
        },
        {
            "icon": "discord",
            "letter": "D",
            "count": 3,
            "focused": false
        }
    ]
    // a strip as wide as the page (SettingsPage)
    readonly property bool pageWide: true
    readonly property real preferredHeight: Math.round(stage.dockHeight * (stage.magnify ? stage.magnifyScale : 1.2) + Space.xl * 2)

    stageHeight: stage.preferredHeight

    StyledRect {
        id: dock
        objectName: "dockShape"
        visible: stage.dockOn && stage.theme !== "integrated"
        anchors.horizontalCenter: parent.horizontalCenter
        width: row.implicitWidth + Math.round(stage.dockHeight - stage.iconSize)
        height: stage.dockHeight
        y: parent.height - height - (stage.floating ? Space.l : Space.s)
        variant: "bg"
        enableShadow: stage.floating
        radius: stage.floating ? Look.radius("round", height) : Math.min(Styling.radius(0), height / 2)
        Behavior on width {
            enabled: Motion.glide.duration > 0
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }

        StageSpot {
            keys: ["dock"]
            cornerRadius: dock.radius
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: stage.spacing

            Icon {
                visible: SettingsStore.get("dock.showPinButton") !== false
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.pin
                size: Math.round(stage.iconSize * 0.7)
                tone: "secondary"
            }
            Repeater {
                model: stage.apps
                delegate: Item {
                    id: app
                    required property var modelData
                    readonly property bool hovered: hover.hovered
                    width: stage.iconSize
                    height: stage.dockHeight
                    z: app.hovered ? 1 : 0

                    Item {
                        id: glyph
                        anchors.centerIn: parent
                        width: stage.iconSize
                        height: stage.iconSize
                        scale: stage.magnify && app.hovered ? stage.magnifyScale : 1
                        transformOrigin: Item.Bottom
                        Behavior on scale {
                            enabled: Motion.micro.duration > 0
                            NumberAnimation {
                                duration: Motion.micro.duration
                            }
                        }
                        Image {
                            id: image
                            anchors.fill: parent
                            source: Quickshell.iconPath(app.modelData.icon, true)
                            sourceSize.width: width * 2
                            sourceSize.height: height * 2
                            smooth: true
                            visible: status === Image.Ready
                        }
                        Mark {
                            anchors.fill: parent
                            visible: image.status !== Image.Ready
                            radius: Look.radius("small", height)
                            color: Qt.alpha(Type.accent, 0.22)
                            KitText {
                                anchors.centerIn: parent
                                role: "secondary"
                                font.weight: Font.DemiBold
                                color: Type.text
                                text: app.modelData.letter
                            }
                        }
                    }
                    // the real indicator style under an app that runs
                    Loader {
                        anchors.fill: parent
                        anchors.bottomMargin: Math.round((stage.dockHeight - stage.iconSize) / 4)
                        active: stage.showRunning && app.modelData.count > 0
                        source: stage.indicatorUrl
                        onLoaded: {
                            item.side = "bottom";
                            item.count = Qt.binding(() => app.modelData.count);
                            item.active = Qt.binding(() => app.modelData.focused);
                            item.size = Qt.binding(() => Math.max(3, Math.round(stage.iconSize * 0.14)));
                        }
                    }
                    HoverHandler {
                        id: hover
                    }
                }
            }
            Icon {
                visible: SettingsStore.get("dock.showOverviewButton") !== false
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.squaresFour
                size: Math.round(stage.iconSize * 0.7)
                tone: "secondary"
            }
        }

        MouseArea {
            objectName: "dockPart"
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: SettingsStore.navigate("dock", "size", "")
        }
    }

    KitText {
        visible: !stage.dockOn || stage.theme === "integrated"
        anchors.centerIn: parent
        role: "secondary"
        text: !stage.dockOn ? I18n.t("prefs.dock.off_stage") : I18n.t("prefs.dock.in_bar_stage")
    }
}
