pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.controls

// theme.weatherFx live: a bar strip and a panel wearing a forced weather
// (WeatherFxScope, runtime only: nothing is stored), cycling through the
// conditions every few seconds; a chip pins one. Shows the configured mode
// (subtle while the feature is off) and language.
PreviewStage {
    id: root

    property var entry
    stageHeight: 190

    readonly property var conditions: ["rain", "drizzle", "snow", "frost", "fog", "heat", "petals", "leaves"]
    property int index: 0
    property bool cycling: true
    readonly property string condition: root.conditions[root.index]

    WeatherFxScope {
        condition: root.condition
    }

    Timer {
        objectName: "weatherFxCycle"
        interval: 5200
        repeat: true
        running: root.cycling && root.visible && WeatherFx.motionOn
        onTriggered: root.index = (root.index + 1) % root.conditions.length
    }

    Column {
        anchors.centerIn: parent
        spacing: Space.m

        Row {
            spacing: Space.l
            anchors.horizontalCenter: parent.horizontalCenter

            StyledRect {
                objectName: "previewBar"
                anchors.verticalCenter: parent.verticalCenter
                variant: "barbg"
                glassSurface: "bar"
                enableShadow: true
                width: Space.controlXL * 2.6
                height: Space.controlM
                radius: Space.surfaceRadius

                KitText {
                    anchors.centerIn: parent
                    role: "caption"
                    text: I18n.t("prefs.weatherfx.cond." + root.condition)
                }
            }
            StyledRect {
                objectName: "previewPanel"
                variant: "popup"
                glassSurface: "popups"
                enableShadow: true
                width: Space.controlXL * 1.5
                height: Space.controlXL
                radius: Space.surfaceRadius

                Column {
                    x: Space.m
                    y: Space.m
                    spacing: Space.s
                    Repeater {
                        model: [0.7, 0.48, 0.6]
                        Rectangle {
                            required property real modelData
                            width: Space.controlXL * 1.5 * modelData
                            height: Space.s
                            radius: height / 2
                            color: Look.alpha("overBackground", 0.3)
                        }
                    }
                }
            }
        }

        Flow {
            spacing: Space.xs
            width: root.width - Space.l * 2
            anchors.horizontalCenter: parent.horizontalCenter

            Chip {
                objectName: "weatherFxAuto"
                text: I18n.t("prefs.weatherfx.cond.auto")
                active: root.cycling
                onClicked: root.cycling = true
            }
            Repeater {
                model: root.conditions
                Chip {
                    required property string modelData
                    required property int index
                    text: I18n.t("prefs.weatherfx.cond." + modelData)
                    active: !root.cycling && root.index === index
                    onClicked: {
                        root.cycling = false;
                        root.index = index;
                    }
                }
            }
        }
    }
}
