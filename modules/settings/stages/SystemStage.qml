pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.config
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Stage of System: your screen (ScreenMini) with the desktop speaking your
// language: the clock with today's date as that language writes it, the
// weather where you are in your unit, and the shell's identity in a corner
// (its mark, name and version). A click on the temperature switches °C and
// °F (one undo step); rows light up their part.
Stage {
    id: stage

    readonly property real u: mini.unit
    // the chosen language (auto: the one the shell resolved)
    readonly property string lang: {
        const v = String(SettingsStore.get("system.language") || "auto");
        return v !== "auto" ? v : (I18n.resolvedLanguage || "en");
    }
    readonly property bool fahrenheit: SettingsStore.get("weather.unit") === "F"
    readonly property string place: String(SettingsStore.get("weather.location") || "")

    stageHeight: Space.px(300)

    ScreenMini {
        id: mini
        anchors.fill: parent
        barOpacity: stage.barOpacity
        cornerRadius: stage.radius
        showWindows: false
        showDock: false

        // the clock, the date, the weather
        Column {
            id: widget
            objectName: "systemClock"
            x: mini.freeRect.x + Math.round(stage.u * 1.4)
            y: mini.freeRect.y + Math.round(stage.u * 1.2)
            spacing: Math.round(stage.u * 0.2)
            KitText {
                role: "display"
                font.pixelSize: Math.round(stage.u * 3.6)
                font.weight: Font.Light
                color: Type.text
                text: "21:47"
            }
            KitText {
                objectName: "systemDate"
                role: "title"
                font.pixelSize: Math.round(stage.u * 0.95)
                color: Type.text
                text: {
                    const s = Qt.locale(stage.lang).toString(new Date(), "dddd, d MMMM");
                    return s.charAt(0).toUpperCase() + s.slice(1);
                }
            }
        }
        StageSpot {
            anchors.fill: widget
            anchors.margins: -Space.s
            keys: ["system.language"]
        }

        // the weather: a click switches the unit
        Mark {
            id: weather
            objectName: "systemWeather"
            x: widget.x
            y: widget.y + widget.height + Math.round(stage.u * 0.7)
            width: weatherRow.implicitWidth + stage.u * 1.2
            height: Math.round(stage.u * 2.1)
            radius: Look.radius("box", height)
            color: Qt.alpha(Colors.surfaceContainer, 0.88)
            border.width: Space.hairline
            border.color: Qt.alpha(Colors.outlineVariant, 0.7)
            Row {
                id: weatherRow
                anchors.centerIn: parent
                spacing: Math.round(stage.u * 0.45)
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.cloudSun
                    size: Math.round(stage.u * 1.2)
                    tone: "accent"
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "title"
                    font.pixelSize: Math.round(stage.u * 0.95)
                    text: stage.fahrenheit ? "70°F" : "21°C"
                }
                Mark {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Space.hairline
                    height: Math.round(stage.u * 0.9)
                    radius: 0
                    color: Type.hairline
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: stage.place ? Icons.mapPin : Icons.magicWand
                    size: Math.round(stage.u * 0.7)
                    tone: "secondary"
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "body"
                    font.pixelSize: Math.round(stage.u * 0.7)
                    color: Type.secondary
                    text: stage.place || I18n.t("prefs.sys.stage.here")
                }
            }
            StageSpot {
                keys: ["weather"]
                cornerRadius: weather.radius
            }
            MouseArea {
                objectName: "systemUnitFlip"
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: SettingsStore.transaction("prefs.undo.unit_changed", () => SettingsStore.set("weather.unit", stage.fahrenheit ? "C" : "F"))
            }
        }

        // the identity, in a corner
        Mark {
            id: badge
            objectName: "systemIdentity"
            anchors.right: parent.right
            anchors.rightMargin: mini.width - mini.freeRect.x - mini.freeRect.w + Math.round(stage.u * 0.8)
            y: mini.freeRect.y + mini.freeRect.h - height - Math.round(stage.u * 0.8)
            width: badgeRow.implicitWidth + stage.u * 1.2
            height: Math.round(stage.u * 2.2)
            radius: Look.radius("box", height)
            color: Qt.alpha(Colors.surfaceContainer, 0.88)
            border.width: Space.hairline
            border.color: Qt.alpha(Colors.outlineVariant, 0.7)
            Row {
                id: badgeRow
                anchors.centerIn: parent
                spacing: Math.round(stage.u * 0.5)
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(stage.u * 1.3)
                    height: width
                    source: Qt.resolvedUrl("../../../assets/yozakura/yozakura-icon.svg")
                    sourceSize.width: width * 2
                    sourceSize.height: height * 2
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        colorization: 1.0
                        brightness: 1.0
                        colorizationColor: Type.accent
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    KitText {
                        role: "body"
                        font.pixelSize: Math.round(stage.u * 0.7)
                        font.weight: Font.Medium
                        text: Brand.displayName
                    }
                    KitText {
                        role: "caption"
                        font.pixelSize: Math.round(stage.u * 0.55)
                        color: Type.muted
                        text: I18n.t("prefs.about.version", Config.version)
                    }
                }
            }
        }
    }
}
