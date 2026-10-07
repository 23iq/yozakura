import QtQuick
import Quickshell.Io
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.config
import "../settings/Ui.js" as Ui
import "OnboardingModel.js" as Model

// One preset in the gallery: a static mini-preview built from the preset's
// bar.json / theme.json, its name and description (info.json). `preset`
// is a PresetsService entry; null is the "keep my current look" card.
Item {
    id: root

    property var preset: null
    property bool selected: false
    property string wallpaper: ""
    property var current: ({})

    signal picked

    readonly property string dir: preset ? preset.path : ""
    property var barJson: null
    property var themeJson: null
    property string description: ""
    readonly property var look: preset ? Model.presetLook(barJson, themeJson, current) : current

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

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Styling.radius(4)
        color: root.selected ? Ui.alpha(Colors.primary, 0.16) : (area.containsMouse ? Ui.alpha(Colors.overBackground, 0.07) : Ui.alpha(Colors.overBackground, 0.035))
        border.width: root.selected ? 2 : 1
        border.color: root.selected ? Colors.primary : Ui.alpha(Colors.overBackground, 0.08)
        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Motion.exit.duration
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Item {
            width: parent.width
            height: Math.round(width * 9 / 16)

            ClippingRectangle {
                anchors.fill: parent
                radius: Math.max(0, Styling.radius(4) - 4)
                color: "transparent"
                PresetPreview {
                    anchors.fill: parent
                    look: root.look
                    wallpaper: root.wallpaper
                }
            }

            Rectangle {
                visible: root.preset === null
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 8
                width: currentText.implicitWidth + 16
                height: currentText.implicitHeight + 6
                radius: height / 2
                color: Colors.primary
                Text {
                    id: currentText
                    anchors.centerIn: parent
                    text: I18n.t("onboarding.preset.current")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
                    font.weight: Font.DemiBold
                    color: Colors.overPrimary
                }
            }

            Rectangle {
                visible: root.selected
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                width: Math.round(Styling.fontSize(0) * 1.7)
                height: width
                radius: width / 2
                color: Colors.primary
                Text {
                    anchors.centerIn: parent
                    text: Icons.accept
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overPrimary
                }
            }
        }

        Text {
            width: parent.width
            text: root.preset ? root.preset.name : I18n.t("onboarding.preset.keep")
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            font.weight: Font.DemiBold
            color: root.selected ? Colors.primary : Colors.overBackground
        }
        Text {
            width: parent.width
            text: root.preset ? (root.description || I18n.t("onboarding.preset.by", root.preset.author || "")) : I18n.t("onboarding.preset.keep.desc")
            // Elides to the room left in the card (fixed grid cell).
            height: Math.max(0, root.height - 16 - y)
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked()
    }
}
