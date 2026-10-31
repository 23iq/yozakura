import QtQuick
import QtQuick.Window
import qs.modules.theme
import qs.modules.components.kit

// The kit's big controls in their states (Tile, LevelSlider, Segmented,
// Sparkline) on one popup surface over the wallpaper. Rendered by
// tools/render/kit_render.py --sheet KitGalleryBold; not shipped.
Window {
    id: win

    property string wallpaper: ""
    property string art: ""
    property string language: ""
    readonly property int colW: 420

    width: colW + 2 * Space.xl
    height: sheet.implicitHeight + 2 * Space.xl
    visible: true
    color: "black"

    Image {
        anchors.fill: parent
        source: win.wallpaper
        fillMode: Image.PreserveAspectCrop
    }

    Surface {
        id: sheet
        x: Space.xl
        y: Space.xl

        Column {
            width: win.colW - 2 * sheet.padding
            spacing: Look.groupGap

            Group {
                width: parent.width
                label: "Segmented · " + win.language
                Segmented {
                    model: [
                        {
                            "name": "a",
                            "icon": Icons.gear,
                            "text": "Home"
                        },
                        {
                            "name": "b",
                            "icon": Icons.image,
                            "text": "Walls"
                        },
                        {
                            "name": "c",
                            "text": "Stats"
                        }
                    ]
                    currentIndex: 0
                }
            }

            Group {
                width: parent.width
                label: "Tiles"
                Row {
                    id: wideRow
                    width: parent.width
                    spacing: Space.s
                    Tile {
                        width: (wideRow.width - Space.s) / 2
                        icon: Icons.wifiHigh
                        text: "Wi-Fi"
                        subtext: "Home 5G"
                        active: true
                        hasMore: true
                    }
                    Tile {
                        width: (wideRow.width - Space.s) / 2
                        icon: Icons.bluetooth
                        text: "Bluetooth"
                        subtext: "Off"
                        hasMore: true
                        highlighted: true
                    }
                }
                Row {
                    id: squareRow
                    width: parent.width
                    spacing: Space.s
                    Repeater {
                        model: [["Mic", true, true, true], ["Silence", false, false, true], ["Night", false, true, true], ["Off", false, false, false], ["", true, false, true]]
                        Tile {
                            required property var modelData
                            width: (squareRow.width - Space.s * 4) / 5
                            vertical: true
                            icon: Icons.bell
                            text: modelData[0]
                            showLabel: modelData[0] !== ""
                            active: modelData[1]
                            highlighted: modelData[2]
                            enabled: modelData[3]
                        }
                    }
                }
            }

            Group {
                width: parent.width
                label: "Level sliders"
                LevelSlider {
                    width: parent.width
                    icon: Icons.speakerHigh
                    value: 0.62
                    hasMore: true
                }
                LevelSlider {
                    width: parent.width
                    icon: Icons.mic
                    value: 0.3
                    level: 0.55
                    hasMore: true
                    moreActive: true
                    highlighted: true
                }
                LevelSlider {
                    width: parent.width
                    icon: Icons.speakerX
                    value: 0.45
                    dimmed: true
                }
                LevelSlider {
                    width: parent.width
                    icon: Icons.sun
                    value: 1
                }
                LevelSlider {
                    width: parent.width
                    height: Space.controlS
                    icon: Icons.sun
                    value: 0
                    enabled: false
                }
            }

            Group {
                width: parent.width
                label: "Sparklines"
                Row {
                    spacing: Space.l
                    Repeater {
                        model: [0.3, 0.75, 0.95]
                        Sparkline {
                            required property real modelData
                            width: Space.controlL * 1.5
                            height: Space.xl
                            color: Type.load(modelData)
                            values: [0.2, 0.4, 0.3, 0.6, 0.5, 0.7, modelData]
                        }
                    }
                }
            }

            Group {
                width: parent.width
                label: "Knobs · readouts"
                Row {
                    spacing: Space.l
                    Knob {
                        value: 0.6
                        detents: 10
                    }
                    Knob {
                        value: 0.3
                        highlighted: true
                        Text {
                            text: Icons.speakerHigh
                            font.family: Icons.font
                            font.pixelSize: Type.iconSize("body")
                            color: Type.text
                        }
                    }
                    Knob {
                        width: Space.controlM
                        height: Space.controlM
                        anchors.verticalCenter: parent.verticalCenter
                        value: 0.85
                        detents: 6
                    }
                    Knob {
                        value: 0.2
                        enabled: false
                    }
                }
                Row {
                    spacing: Space.s
                    Well {
                        width: clockDigits.width + Space.l * 2
                        height: clockDigits.height + Space.m * 2
                        SegmentDigits {
                            id: clockDigits
                            anchors.centerIn: parent
                            text: "21:05"
                            digitHeight: Type.size("display")
                        }
                    }
                    Well {
                        width: smallDigits.width + Space.m * 2
                        height: smallDigits.height + Space.m * 2
                        anchors.bottom: parent.bottom
                        SegmentDigits {
                            id: smallDigits
                            anchors.centerIn: parent
                            text: "-12.5"
                            color: Type.text
                            digitHeight: Type.size("title") * 1.2
                        }
                    }
                    Well {
                        width: hexDigits.width + Space.m * 2
                        height: hexDigits.height + Space.m * 2
                        anchors.bottom: parent.bottom
                        SegmentDigits {
                            id: hexDigits
                            anchors.centerIn: parent
                            text: " 0FF"
                            color: Type.secondary
                            digitHeight: Type.size("title") * 1.2
                        }
                    }
                }
            }
        }
    }
}
