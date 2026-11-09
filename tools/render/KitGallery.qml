import QtQuick
import QtQuick.Window
import qs.modules.theme
import qs.modules.components.kit

// Design-system sheet of the shared kit (modules/components/kit): every
// component in its states, grouped with Group, on three popup surfaces over the wallpaper.
// Rendered by tools/render/kit_render.py; not shipped.
Window {
    id: win

    property string wallpaper: ""
    property string art: ""
    property string language: ""
    readonly property int colW: 344

    width: 3 * colW + 4 * Space.xl
    height: Math.max(colA.implicitHeight, colB.implicitHeight, colC.implicitHeight) + 2 * Space.xl
    visible: true
    color: "black"

    Image {
        anchors.fill: parent
        source: win.wallpaper
        fillMode: Image.PreserveAspectCrop
    }

    Row {
        x: Space.xl
        y: Space.xl
        spacing: Space.xl

        // Type and structure
        Surface {
            id: colA
            Column {
                width: win.colW - 2 * colA.padding
                spacing: Look.groupGap

                Group {
                    width: parent.width
                    label: "Type · " + win.language
                    KitText {
                        role: "display"
                        text: "21:47"
                    }
                    Column {
                        width: parent.width
                        spacing: Space.xs
                        KitText {
                            role: "title"
                            text: "Good evening, Lazy"
                        }
                        KitText {
                            width: parent.width
                            role: "body"
                            text: "Three meetings left today. The first one starts in forty minutes."
                            wrapMode: Text.WordWrap
                            elide: Text.ElideNone
                        }
                    }
                    KitText {
                        role: "secondary"
                        text: "Next: Design review at 22:30"
                    }
                    KitText {
                        role: "caption"
                        text: "Updated 2 minutes ago"
                    }
                }
                Group {
                    width: parent.width
                    divider: true
                    label: "Network"
                    actionText: "Settings"
                    Row {
                        spacing: Space.m
                        height: Type.size("secondary") + Space.s
                        KitText {
                            role: "secondary"
                            text: "Wi-Fi"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Divider {
                            vertical: true
                            height: parent.height
                        }
                        KitText {
                            role: "secondary"
                            text: "Bluetooth"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Divider {
                            vertical: true
                            height: parent.height
                        }
                        KitText {
                            role: "secondary"
                            text: "VPN off"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                Group {
                    width: parent.width
                    divider: true
                    label: "Shortcuts"
                    Row {
                        spacing: Space.xs
                        KeyHint {
                            text: "Super"
                        }
                        KeyHint {
                            text: "Space"
                        }
                        Item {
                            width: Space.s
                            height: 1
                        }
                        KeyHint {
                            icon: Icons.arrowUp
                        }
                        KeyHint {
                            icon: Icons.arrowDown
                        }
                        KeyHint {
                            icon: Icons.arrowElbowDownLeft
                        }
                        Item {
                            width: Space.s
                            height: 1
                        }
                        KeyHint {
                            text: "Esc"
                        }
                    }
                    KitText {
                        role: "caption"
                        text: "Open the launcher, move, run, close"
                    }
                }
                // Icon: role-sized glyphs in ink tones
                Group {
                    width: parent.width
                    divider: true
                    label: "Icon"
                    Row {
                        spacing: Space.m
                        Repeater {
                            model: [["title", "text"], ["body", "text"], ["secondary", "secondary"], ["caption", "muted"], ["body", "accent"], ["body", "progress"]]
                            Icon {
                                required property var modelData
                                anchors.verticalCenter: parent.verticalCenter
                                icon: Icons.gear
                                role: modelData[0]
                                tone: modelData[1]
                            }
                        }
                    }
                    KitText {
                        width: parent.width
                        role: "caption"
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                        text: "title · body · secondary · caption/muted · accent · progress"
                    }
                }
                // Look.radius(role): the one radius API
                Group {
                    width: parent.width
                    divider: true
                    label: "Radius"
                    Flow {
                        width: parent.width
                        spacing: Space.s
                        Repeater {
                            model: ["surface", "group", "box", "big", "control", "chip", "button", "small", "round"]
                            Column {
                                id: swatch
                                required property string modelData
                                spacing: Space.xs
                                Rectangle {
                                    width: Space.controlS
                                    height: Space.controlS
                                    radius: Look.radius(swatch.modelData, height)
                                    color: Look.raisedFill(false)
                                    border.width: Space.hairline
                                    border.color: Type.track
                                }
                                KitText {
                                    width: Space.controlS
                                    role: "caption"
                                    font.pixelSize: Type.size("label")
                                    horizontalAlignment: Text.AlignHCenter
                                    text: swatch.modelData
                                }
                            }
                        }
                    }
                }
            }
        }

        KitGalleryControls {
            id: colB
            width: win.colW
            art: win.art
        }

        KitGalleryLists {
            id: colC
            width: win.colW
            art: win.art
        }
    }
}
