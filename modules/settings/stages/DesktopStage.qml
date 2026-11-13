pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.store
import "../../desktop/widgets/WidgetRegistry.js" as Registry
import "../SchemaUtil.js" as SchemaUtil
import "../Ui.js" as Ui
import "DesktopPlace.js" as DesktopPlace
import "../../desktop/clockstyles/ClockStyleRegistry.js" as ClockStyles

// Stage of Widgets: your desktop with no windows on it, drawn from the live
// config: the depth clock as it renders (the real DepthClock, its style,
// ink and subject cutout, built off the first frame), every desktop widget
// where it sits (desktop.widgets, fractions of the screen) on the widget
// surface, and the desktop icons in their size. A widget turned on from
// its chip appears here at once. With the clock on, the other side of the
// screen is a dashed "move here" zone (desktop.depthClockPosition).
Stage {
    id: stage
    objectName: "desktopStage"

    readonly property bool widgetsOn: SettingsStore.get("desktop.widgetsEnabled") !== false
    readonly property var widgets: stage.widgetsOn ? Registry.normalizeList(SchemaUtil.plain(SettingsStore.get("desktop.widgets")) || []) : []
    readonly property string variant: String(SettingsStore.get("desktop.widgetVariant") || "pane")
    readonly property bool clockOn: SettingsStore.get("desktop.depthClock") === true
    readonly property string clockStyle: String(SettingsStore.get("desktop.depthClockStyle") || "")
    readonly property string clockInk: String(SettingsStore.get("desktop.depthClockInk") || "auto")
    // where the clock is drawn (its real placement), else where the setting says
    readonly property string clockSide: DesktopPlace.clockSide(String(SettingsStore.get("desktop.depthClockPosition") || "auto"), String(Ui.prop(clock.item, "side") ?? ""))
    // the other side, where this style can go ("": none)
    readonly property string clockTarget: DesktopPlace.moveTarget(stage.clockSide, ClockStyles.get(stage.clockStyle).sides)
    readonly property bool iconsOn: SettingsStore.get("desktop.enabled") === true
    readonly property real iconSize: Number(SettingsStore.get("desktop.iconSize") || 48)
    readonly property string iconInk: String(SettingsStore.get("desktop.textColor") || "overBackground")
    property bool hoverZone: false

    stageHeight: Space.px(300)

    // the depth clock: the real one, by URL, built after the first frame
    Loader {
        id: clock
        objectName: "desktopClock"
        anchors.fill: parent
        active: stage.clockOn
        asynchronous: true
        visible: status === Loader.Ready
        source: Qt.resolvedUrl("../previews/ClockStyleScene.qml")
        onLoaded: {
            item.styleId = Qt.binding(() => stage.clockStyle);
            item.inkRole = Qt.binding(() => stage.clockInk);
            item.crop = false;
        }
    }

    ScreenMini {
        id: mini
        anchors.fill: parent
        barOpacity: stage.barOpacity
        cornerRadius: stage.radius
        showWindows: false

        // the desktop icons, top left, in their size and ink
        Column {
            id: icons
            objectName: "desktopIcons"
            visible: stage.iconsOn
            x: mini.freeRect.x + mini.unit * 0.5
            y: mini.freeRect.y + mini.unit * 0.5
            spacing: Math.round(mini.unit * 0.3)
            readonly property real glyph: Math.max(Space.px(10), stage.iconSize * mini.width / 1920)
            Repeater {
                model: ["folder", "fileText", "image"]
                delegate: Column {
                    required property string modelData
                    spacing: Space.hairline * 2
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon: Icons[parent.modelData] ?? ""
                        size: Math.round(icons.glyph)
                        color: Colors[stage.iconInk] ?? Type.text
                    }
                    Mark {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: icons.glyph * 1.2
                        height: Math.max(2, Math.round(mini.unit * 0.16))
                        color: Qt.alpha(Colors[stage.iconInk] ?? Type.text, 0.7)
                    }
                }
            }
        }
        StageSpot {
            anchors.fill: icons
            visible: icons.visible && opacity > 0
            keys: ["desktop.enabled", "desktop.iconSize", "desktop.textColor"]
        }

        // the widgets where they sit
        Repeater {
            model: stage.widgets
            delegate: Item {
                id: widget
                required property var modelData
                readonly property var type: Registry.get(modelData.type) || {}
                objectName: "desktopWidgetMini:" + modelData.type
                x: modelData.x * mini.width
                y: modelData.y * mini.height
                width: Math.max(mini.unit * 2, modelData.w * mini.width)
                height: Math.max(mini.unit * 1.5, modelData.h * mini.height)

                // its footprint (a see-through surface still reads as a widget)
                Mark {
                    anchors.fill: parent
                    radius: Look.radius("small", Math.min(width, height))
                    color: Qt.alpha(Colors.background, 0.35)
                    border.width: Space.hairline
                    border.color: Type.hairline
                }
                StyledRect {
                    anchors.fill: parent
                    variant: stage.variant
                    enableShadow: false
                    radius: Look.radius("small", Math.min(width, height))
                }
                Icon {
                    x: Math.round(mini.unit * 0.35)
                    y: Math.round(mini.unit * 0.3)
                    icon: Icons[widget.type.icon] ?? ""
                    role: "secondary"
                    tone: "accent"
                }
                Column {
                    x: Math.round(mini.unit * 0.35)
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(mini.unit * 0.35)
                    spacing: Math.round(mini.unit * 0.18)
                    Repeater {
                        model: 2
                        delegate: Mark {
                            required property int index
                            width: widget.width * (index === 0 ? 0.55 : 0.34)
                            height: Math.max(2, Math.round(mini.unit * 0.16))
                            color: Qt.alpha(Type.text, index === 0 ? 0.6 : 0.3)
                        }
                    }
                }
                StageSpot {
                    keys: ["desktop.widgets", "desktop.widgetVariant", "desktop.widgetsEnabled"]
                }
            }
        }

        // the clock's other side: move it there
        Item {
            id: zone
            objectName: "desktopClockZone"
            visible: stage.clockOn && zone.side !== ""
            readonly property string side: stage.clockTarget
            width: mini.freeRect.w * 0.34
            height: mini.freeRect.h * 0.36
            x: zone.side === "left" ? mini.freeRect.x + mini.unit : mini.freeRect.x + mini.freeRect.w - width - mini.unit
            y: mini.freeRect.y + (mini.freeRect.h - height) / 2
            DashedFrame {
                anchors.fill: parent
                radius: Look.radius("box", Space.controlL)
                fill: Qt.alpha(Type.accent, stage.hoverZone ? 0.24 : 0.06)
            }
            Row {
                anchors.centerIn: parent
                spacing: Space.xs
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: zone.side === "left" ? Icons.arrowLeft : Icons.arrowRight
                    role: "caption"
                    tone: "accent"
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "caption"
                    color: Type.text
                    text: I18n.t("prefs.home.move_here")
                }
            }
            MouseArea {
                objectName: "desktopClockZoneArea"
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: stage.hoverZone = containsMouse
                onClicked: SettingsStore.transaction("prefs.undo.clock_moved", () => SettingsStore.set("desktop.depthClockPosition", zone.side))
            }
            StageSpot {
                keys: ["desktop.depthClockPosition"]
            }
        }
    }
}
