import QtQuick
import Quickshell.Io
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import "OnboardingModel.js" as Model

// One preset in the gallery: a selectable thumbnail card (raised fill;
// selected = accent tint, accent edge and a check) with a static
// mini-preview built from the preset's bar.json / theme.json, its name and
// description (info.json). `preset` is a PresetsService entry; null is the
// "keep my current look" card. The grid owns the keyboard: `focused` shows
// the focus ring on its current card.
Item {
    id: root

    property var preset: null
    property bool selected: false
    property bool focused: false
    property string wallpaper: ""
    property var current: ({})

    signal picked

    readonly property string dir: preset ? preset.path : ""
    property var barJson: null
    property var themeJson: null
    property string description: ""
    readonly property var look: preset ? Model.presetLook(barJson, themeJson, current) : current
    readonly property real radius: Look.bigRadius(root.height)
    readonly property bool hovered: area.containsMouse

    objectName: "presetCard:" + (root.preset ? root.preset.name : "")

    function parse(view) {
        try {
            return JSON.parse(view.text());
        } catch (e) {
            return null;
        }
    }

    FileView {
        path: root.dir ? root.dir + "/bar.json" : ""
        onLoaded: root.barJson = root.parse(this)
    }
    FileView {
        path: root.dir ? root.dir + "/theme.json" : ""
        onLoaded: root.themeJson = root.parse(this)
    }
    FileView {
        path: root.dir ? root.dir + "/info.json" : ""
        onLoaded: {
            const info = root.parse(this);
            root.description = info && info.description ? info.description : "";
        }
    }

    // The card's box: the kit's raised fill, an accent tint when selected.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.selected ? Qt.alpha(Type.accent, Look.activeTint) : Look.raisedFill(root.hovered)
        border.width: root.selected ? Space.stroke - 1 : (Look.controlEdge.a > 0 ? Space.hairline : 0)
        border.color: root.selected ? Type.accent : Look.controlEdge
        Behavior on color {
            enabled: Motion.micro.duration > 0
            ColorAnimation {
                duration: Motion.micro.duration
                easing.type: Motion.micro.easing
            }
        }
    }

    FocusRing {
        shown: root.focused
        radius: root.radius + Space.stroke
    }

    Column {
        id: body
        anchors.fill: parent
        anchors.margins: Space.s
        spacing: Space.s

        Item {
            width: parent.width
            height: Math.round(width * 9 / 16)

            // Image clip of the illustration.
            ClippingRectangle {
                anchors.fill: parent
                radius: Space.clampRadius(Space.controlRadius, height)
                color: Type.placeholder
                PresetPreview {
                    anchors.fill: parent
                    look: root.look
                    wallpaper: root.wallpaper
                }
            }

            StyledRect {
                visible: root.preset === null
                variant: "popup"
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Space.s
                width: currentText.implicitWidth + Space.m * 2
                height: currentText.implicitHeight + Space.xs * 2
                radius: Look.chipRadius(height)
                KitText {
                    id: currentText
                    anchors.centerIn: parent
                    role: "caption"
                    color: Type.text
                    text: I18n.t("onboarding.preset.current")
                }
            }

            // The selected mark: an accent disc with a check.
            Rectangle {
                visible: root.selected
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Space.s
                width: Space.px(24)
                height: width
                radius: width / 2
                color: Type.accent
                Text {
                    anchors.centerIn: parent
                    text: Icons.accept
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("caption")
                    color: Type.accentInk
                }
            }
        }

        KitText {
            id: name
            width: parent.width
            leftPadding: Space.xs
            rightPadding: Space.xs
            role: "body"
            font.weight: Font.DemiBold
            text: root.preset ? root.preset.name : I18n.t("onboarding.preset.keep")
        }

        KitText {
            width: parent.width
            leftPadding: Space.xs
            rightPadding: Space.xs
            role: "secondary"
            verticalAlignment: Text.AlignTop
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            text: root.preset ? (root.description || I18n.t("onboarding.preset.by", root.preset.author || "")) : I18n.t("onboarding.preset.keep.desc")
        }
    }

    // The selected name takes the accent; otherwise the role's own ink.
    Binding {
        target: name
        property: "color"
        value: Type.accent
        when: root.selected
    }

    // Pointer path; the keyboard goes through the grid (arrows + Enter).
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked()
    }
}
