import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// KitGallery column: list rows, sliders, progress and rings.
Surface {
    id: root

    property string art: ""

    Column {
        width: root.width - 2 * root.padding
        spacing: Space.m

        SectionLabel {
            width: parent.width
            text: "Notifications"
            action: "Clear"
        }
        Column {
            width: parent.width
            spacing: 2
            ListRow {
                width: parent.width
                title: "Mira Tanaka"
                subtitle: "Sent the deck, take a look before the review tonight"
                leading: Component {
                    Avatar {
                        name: "Mira Tanaka"
                    }
                }
                trailing: Component {
                    KitText {
                        role: "caption"
                        text: "2m"
                    }
                }
            }
            ListRow {
                width: parent.width
                title: "Firefox"
                subtitle: "Download complete · report-q3.pdf"
                highlighted: true
                leading: Component {
                    Art {
                        icon: Icons.downloadSimple
                    }
                }
                trailing: Component {
                    KeyHint {
                        icon: Icons.arrowElbowDownLeft
                    }
                }
            }
            ListRow {
                width: parent.width
                title: "Kōyō"
                subtitle: "Warm autumn palette"
                selected: true
                leading: Component {
                    Art {
                        source: root.art
                    }
                }
                trailing: Component {
                    Text {
                        text: Icons.check
                        font.family: Icons.font
                        font.pixelSize: Type.iconSize("body")
                        color: Type.accent
                    }
                }
            }
        }

        SectionLabel {
            width: parent.width
            text: "Levels"
        }
        LineSlider {
            width: parent.width
            icon: Icons.speakerHigh
            value: 0.62
            showValue: true
        }
        LineSlider {
            width: parent.width
            icon: Icons.sun
            value: 0.38
            showValue: true
            highlighted: true
        }

        Row {
            width: parent.width
            spacing: Space.l
            LineSlider {
                vertical: true
                height: 132
                icon: Icons.speakerHigh
                value: 0.7
                showValue: true
            }
            LineSlider {
                vertical: true
                height: 132
                icon: Icons.mic
                value: 0.3
                showValue: true
                highlighted: true
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.s
                Ring {
                    width: 84
                    height: 84
                    value: 0.64
                    Column {
                        KitText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            role: "title"
                            tabular: true
                            text: "18:24"
                        }
                        KitText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            role: "label"
                            text: "Focus"
                        }
                    }
                }
            }
            Ring {
                anchors.verticalCenter: parent.verticalCenter
                width: 56
                height: 56
                value: 0.35
                Text {
                    text: Icons.shutdown
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("title")
                    color: Type.text
                }
            }
        }

        Column {
            width: parent.width
            spacing: Space.xs
            Item {
                width: parent.width
                height: up.implicitHeight
                KitText {
                    id: up
                    role: "secondary"
                    text: "Uploading photos"
                }
                KitText {
                    anchors.right: parent.right
                    role: "caption"
                    tabular: true
                    text: "35%"
                }
            }
            ProgressLine {
                width: parent.width
                value: 0.35
            }
        }
    }
}
