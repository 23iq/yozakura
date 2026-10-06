import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// KitGallery column: icon buttons, chips and a media card.
Surface {
    id: root

    property string art: ""

    component Labeled: Column {
        id: lab
        property string caption: ""
        default property alias inner: holder.data
        spacing: Space.xs
        Item {
            id: holder
            anchors.horizontalCenter: parent.horizontalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
        KitText {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "caption"
            text: lab.caption
        }
    }

    Column {
        width: root.width - 2 * root.padding
        spacing: Space.m

        SectionLabel {
            width: parent.width
            text: "Icon buttons"
        }
        Row {
            spacing: Space.m
            Labeled {
                caption: "rest"
                IconButton {
                    icon: Icons.gear
                }
            }
            Labeled {
                caption: "hover"
                IconButton {
                    icon: Icons.moon
                    highlighted: true
                }
            }
            Labeled {
                caption: "active"
                IconButton {
                    icon: Icons.bellSlash
                    active: true
                }
            }
            Labeled {
                caption: "off"
                IconButton {
                    icon: Icons.trash
                    enabled: false
                }
            }
            Labeled {
                caption: "primary"
                IconButton {
                    icon: Icons.paperPlaneRight
                    primary: true
                }
            }
        }
        Row {
            spacing: Space.s
            IconButton {
                size: "s"
                icon: Icons.wifiHigh
                active: true
            }
            IconButton {
                size: "s"
                icon: Icons.bluetooth
            }
            IconButton {
                size: "s"
                icon: Icons.nightLight
            }
            IconButton {
                size: "s"
                icon: Icons.speakerHigh
                highlighted: true
            }
            IconButton {
                size: "s"
                icon: Icons.shutdown
            }
        }

        SectionLabel {
            width: parent.width
            text: "Chips"
        }
        Flow {
            width: parent.width
            spacing: Space.s
            Chip {
                icon: Icons.wifiHigh
                text: "Home 5G"
                active: true
            }
            Chip {
                icon: Icons.bluetooth
                text: "Bluetooth"
            }
            Chip {
                icon: Icons.nightLight
                text: "Night light"
                highlighted: true
            }
            Chip {
                icon: Icons.bellSlash
                text: "Silent"
                active: true
            }
            Chip {
                text: "All day"
            }
        }

        SectionLabel {
            width: parent.width
            text: "Now playing"
            action: "Open"
        }
        Row {
            width: parent.width
            spacing: Space.m
            Art {
                width: 56
                height: 56
                source: root.art
            }
            Column {
                width: parent.width - 56 - Space.m
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                KitText {
                    width: parent.width
                    role: "body"
                    font.weight: Font.Medium
                    text: "Midnight City"
                }
                KitText {
                    width: parent.width
                    role: "secondary"
                    text: "M83 · Hurry Up, We're Dreaming"
                }
            }
        }
        Column {
            width: parent.width
            spacing: Space.xs
            ProgressLine {
                width: parent.width
                value: 0.42
            }
            Item {
                width: parent.width
                height: elapsed.implicitHeight
                KitText {
                    id: elapsed
                    role: "caption"
                    tabular: true
                    text: "1:44"
                }
                KitText {
                    anchors.right: parent.right
                    role: "caption"
                    tabular: true
                    text: "4:03"
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Space.l
            IconButton {
                icon: Icons.shuffle
                size: "s"
                anchors.verticalCenter: parent.verticalCenter
            }
            IconButton {
                icon: Icons.previous
                anchors.verticalCenter: parent.verticalCenter
            }
            IconButton {
                icon: Icons.pause
                primary: true
                anchors.verticalCenter: parent.verticalCenter
            }
            IconButton {
                icon: Icons.next
                anchors.verticalCenter: parent.verticalCenter
            }
            IconButton {
                icon: Icons.repeat
                size: "s"
                active: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
