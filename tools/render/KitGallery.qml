import QtQuick
import QtQuick.Window
import qs.modules.theme
import qs.modules.components.kit

// Design-system sheet of the shared kit (modules/components/kit): every
// component in its states, on three popup surfaces over the wallpaper.
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
                width: win.colW - 2 * Space.l
                spacing: Space.m

                SectionLabel {
                    width: parent.width
                    text: "Type · " + win.language
                }
                KitText {
                    role: "display"
                    text: "21:47"
                }
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
                KitText {
                    role: "secondary"
                    text: "Next: Design review at 22:30"
                }
                KitText {
                    role: "caption"
                    text: "Updated 2 minutes ago"
                }
                Divider {
                    width: parent.width
                }
                SectionLabel {
                    width: parent.width
                    text: "Network"
                    action: "Settings"
                }
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
                Divider {
                    width: parent.width
                }
                SectionLabel {
                    width: parent.width
                    text: "Shortcuts"
                }
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
