pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.store

// Stage of Look > Theme: a corner of your desktop drawn with the real kit.
// The bar, a quick settings panel (a selected row with the brush
// signature, switches, a level slider, a segmented choice) and a
// notification are the shell's own components on the theme's own
// surfaces, so mode, visual style, palette, roundness, density, glass,
// depth, lighting and the signatures show here exactly as on the desktop,
// the moment they change. Rows light up the part they change.
Stage {
    id: stage

    stageHeight: Space.px(330)

    readonly property var lookKeys: ["theme", "wallpaper.matugenScheme", "compositor.gapsIn", "compositor.gapsOut"]

    // A window behind the panels.
    Mark {
        x: stage.width * 0.36
        y: barStrip.height + Space.xl
        width: stage.width * 0.6
        height: stage.height - y - Space.xl
        radius: Look.radius("surface", height)
        color: Qt.alpha(Colors.surfaceContainer, 0.7)
        border.width: Space.hairline
        border.color: Qt.alpha(Colors.outlineVariant, 0.6)

        Column {
            x: Space.xl
            y: Space.xl
            spacing: Space.m
            Repeater {
                model: 5
                delegate: Mark {
                    required property int index
                    width: stage.width * (index === 0 ? 0.18 : 0.4 - index * 0.05)
                    height: index === 0 ? Space.m : Space.s
                    color: Qt.alpha(Colors.overSurface, index === 0 ? 0.45 : 0.18)
                }
            }
        }
    }

    // The bar.
    StyledRect {
        id: barStrip
        width: stage.width
        height: Space.px(36)
        variant: "barbg"
        backgroundOpacity: stage.barOpacity
        enableShadow: false
        radius: 0

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Space.l
            anchors.rightMargin: Space.l
            spacing: Space.l
            Icon {
                objectName: "lookStageIcon"
                icon: Icons.launch
                role: "body"
                tone: "accent"
            }
            Repeater {
                model: ["squaresFour", "wifiHigh", "speakerHigh"]
                delegate: Icon {
                    required property string modelData
                    icon: Icons[modelData] ?? ""
                    role: "body"
                    tone: "text"
                }
            }
            Item {
                Layout.fillWidth: true
            }
            KitText {
                role: "body"
                tabular: true
                text: "21:47"
            }
        }
    }
    StageSpot {
        anchors.fill: barStrip
        keys: ["theme.icons", "theme.tintIcons", "theme.srBarBg"]
        cornerRadius: 0
    }

    // Quick settings: real kit controls on the theme's popup surface.
    Surface {
        id: panel
        objectName: "lookStagePanel"
        x: Space.xl
        y: barStrip.height + Space.l
        width: Math.min(Space.px(320), stage.width * 0.42)
        enableShadow: true

        ColumnLayout {
            width: panel.width - panel.padding * 2
            spacing: Space.s

            SectionLabel {
                Layout.fillWidth: true
                text: I18n.t("prefs.look.stage.quick")
            }
            ListRow {
                id: selectedRow
                Layout.fillWidth: true
                title: I18n.t("prefs.dest.network")
                subtitle: "Sakura 5G"
                selected: true
                leading: Component {
                    Icon {
                        icon: Icons.wifiHigh
                        tone: "accent"
                    }
                }
                trailing: Component {
                    Switch {
                        checked: true
                    }
                }
            }
            ListRow {
                Layout.fillWidth: true
                title: I18n.t("prefs.dest.notifications")
                leading: Component {
                    Icon {
                        icon: Icons.bell
                        tone: "secondary"
                    }
                }
                trailing: Component {
                    Switch {
                        checked: false
                    }
                }
            }
            LineSlider {
                Layout.fillWidth: true
                icon: Icons.speakerHigh
                value: 0.62
                showValue: true
                StageSpot {
                    keys: ["theme.progressRole"]
                }
            }
            Segmented {
                Layout.alignment: Qt.AlignHCenter
                model: [
                    {
                        "name": "seg:dark",
                        "icon": Icons.moon,
                        "text": ""
                    },
                    {
                        "name": "seg:light",
                        "icon": Icons.sun,
                        "text": ""
                    },
                    {
                        "name": "seg:auto",
                        "icon": Icons.circleHalf,
                        "text": ""
                    }
                ]
                currentIndex: 0
            }
        }
    }
    StageSpot {
        x: panel.x + selectedRow.x + panel.padding
        y: panel.y + selectedRow.y + panel.padding
        width: selectedRow.width
        height: selectedRow.height
        anchors.fill: undefined
        keys: ["theme.signatures.brushHighlight"]
    }
    StageSpot {
        anchors.fill: panel
        keys: stage.lookKeys
        cornerRadius: panel.radius
        spread: Space.s
    }

    // A notification.
    Surface {
        id: toast
        x: stage.width - width - Space.xl
        y: barStrip.height + Space.l
        width: Math.min(Space.px(300), stage.width * 0.36)
        enableShadow: true

        RowLayout {
            width: toast.width - toast.padding * 2
            spacing: Space.m
            Avatar {
                name: "Yuki"
                Layout.alignment: Qt.AlignTop
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Space.hairline
                KitText {
                    Layout.fillWidth: true
                    role: "body"
                    text: "Yuki"
                    font.weight: Look.activeLabelWeight
                }
                KitText {
                    Layout.fillWidth: true
                    role: "secondary"
                    text: I18n.t("prefs.look.stage.message")
                    elide: Text.ElideRight
                }
            }
        }
    }
}
