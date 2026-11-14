pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.components.kit

// A picture card: one look to pick, shown as a picture (default children,
// clipped to the card's rounded corners) over a short title. Used by every
// "pick one of these looks" row. At rest the picture has a hairline edge;
// hovered it lifts a little and the edge firms up; `selected` rings it in
// the accent (inside its edge), puts a check badge in its corner and the
// title in the active weight. Keyboard:
// Tab focus with the kit FocusRing, Space / Enter pick. The same in every
// visual language (the picture is the box). `subtitle` is a second caption
// line for the rare card whose picture cannot say it. `inset`: the title
// sits inside the picture on a gradient (a strip of pictures in a card of
// the page row), no caption under it.
Item {
    id: card

    property bool selected: false
    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property real previewHeight: 96
    property bool inset: false
    default property alias preview: previewArea.data
    readonly property bool hovered: area.containsMouse
    readonly property real radius: Look.radius("control", Space.controlL)
    signal clicked

    implicitWidth: Space.px(180)
    implicitHeight: card.inset ? card.previewHeight : card.previewHeight + Space.s + caption.implicitHeight
    activeFocusOnTab: true
    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()

    Accessible.role: Accessible.RadioButton
    Accessible.name: title
    Accessible.checked: selected

    Item {
        id: frame
        width: parent.width
        height: card.previewHeight
        y: card.hovered && !card.selected ? -Space.hairline * 2 : 0
        Behavior on y {
            enabled: Motion.micro.duration > 0
            NumberAnimation {
                duration: Motion.micro.duration
                easing.type: Motion.micro.easing
            }
        }

        Item {
            id: previewArea
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: mask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }
        Mark {
            id: mask
            anchors.fill: parent
            radius: card.radius
            visible: false
            layer.enabled: true
            layer.smooth: true
        }

        // inset title: on a gradient at the bottom of the picture
        Mark {
            visible: card.inset
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.min(parent.height, insetTitle.implicitHeight + Space.l * 2)
            radius: card.radius
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Colors.shadow, 0.75)
                }
            }
            KitText {
                id: insetTitle
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Space.s
                width: Math.min(implicitWidth, parent.width - Space.s * 2)
                role: "secondary"
                color: Qt.rgba(1, 1, 1, card.selected ? 1 : 0.85)
                font.weight: card.selected ? Look.activeLabelWeight : Look.labelWeight
                text: card.title
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }

        // The edge: a hairline at rest, the accent ring when selected (drawn
        // inside the picture: never cut by the card or row that holds it).
        Mark {
            anchors.fill: parent
            radius: card.radius
            color: "transparent"
            border.width: card.selected ? Space.stroke : Space.hairline
            border.color: card.selected ? Type.accent : (card.hovered ? Type.track : Type.hairline)
            Behavior on border.color {
                enabled: Motion.micro.duration > 0
                ColorAnimation {
                    duration: Motion.micro.duration
                }
            }
        }
        // The chosen one also carries a check badge: the choice reads
        // without telling the accent from the hairline. It sits on the
        // picture's corner, mostly outside it, ringed in the card colour
        // (never over the thumb's content), smaller on a small picture.
        Mark {
            objectName: "choiceBadge"
            visible: card.selected
            width: Math.max(Space.px(16), Math.min(Math.round(Type.iconSize("caption") * 1.7), Math.round(Math.min(parent.width, parent.height) * 0.3)))
            height: width
            x: parent.width - width * 0.65
            y: -width * 0.35
            z: 2
            color: Type.accent
            border.width: Space.stroke - 1
            border.color: Qt.rgba(Look.cardFill(false).r, Look.cardFill(false).g, Look.cardFill(false).b, 1)
            Icon {
                anchors.centerIn: parent
                icon: Icons.accept
                role: "caption"
                tone: "accentInk"
                scale: Math.min(1, (parent.width - Space.xs) / implicitWidth)
            }
        }

        FocusRing {
            shown: card.activeFocus
            anchors.margins: -Space.stroke * 2
            radius: card.radius + Space.stroke * 2
        }
    }

    // a narrow card (the compact picture grids): the description is the
    // tooltip, not a line under the name
    readonly property bool compactCaption: card.width < Space.px(180)
    Tooltip {
        text: card.subtitle
        shown: card.compactCaption && card.subtitle !== "" && card.hovered
    }

    Row {
        id: caption
        visible: !card.inset
        anchors.top: frame.bottom
        anchors.topMargin: Space.s
        x: Space.xs
        width: parent.width - Space.xs * 2
        spacing: Space.s

        Icon {
            id: lead
            visible: card.icon !== ""
            // on the name's first line (a name on two lines keeps its
            // glyph beside its start, not between the lines)
            y: Math.round((titleText.implicitHeight / Math.max(1, titleText.lineCount) - lead.implicitHeight) / 2)
            icon: Icons[card.icon] ?? ""
            role: "secondary"
            tone: card.selected ? "accent" : "secondary"
        }
        Column {
            id: titleCol
            width: parent.width - (lead.visible ? lead.width + parent.spacing : 0)
            // the name, whole (as many lines as it needs: a translation is
            // never cut; the pictures of a row stay aligned on top); the
            // chosen one in the text colour and the active weight
            KitText {
                id: titleText
                width: parent.width
                role: "secondary"
                color: card.selected ? Type.text : Type.secondary
                font.weight: card.selected ? Look.activeLabelWeight : Look.labelWeight
                text: card.title
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
            // a compact card keeps its description for the tooltip
            KitText {
                width: parent.width
                visible: card.subtitle !== "" && !card.compactCaption
                role: "caption"
                text: card.subtitle
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            card.forceActiveFocus();
            card.clicked();
        }
    }
}
