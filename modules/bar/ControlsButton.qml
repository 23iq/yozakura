pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.bar.look
import qs.modules.theme
import qs.modules.shell.osd.styles

// Bar "controls" module: a faders glyph; left click opens the levels popup
// (volume, microphone, brightness as kit LineSliders, the glyph toggles
// mute), right click opens pavucontrol.
Item {
    id: root

    required property var bar

    property bool vertical: bar.orientation === "vertical"
    property bool isHovered: false
    property bool layerEnabled: true

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius
    // Bar panels: module size, and "flat" (no group box of its own)
    property int moduleSize: BarMetrics.moduleSize
    property bool flat: false

    // Popup visibility state (tracks intent, not animation)
    property bool popupOpen: controlsPopup.isOpen

    objectName: "controlsModule"
    // The OSD bar-inline style grows the button into a level slider.
    Layout.preferredWidth: root.moduleSize + (root.vertical ? 0 : inlineOsd.reveal)
    Layout.preferredHeight: root.moduleSize + (root.vertical ? inlineOsd.reveal : 0)
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical

    StyledToolTip {
        show: root.isHovered && !root.popupOpen
        tooltipText: I18n.t("bar.tooltip.controls")
    }

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    Item {
        id: buttonBg
        anchors.fill: parent

        ModuleBox {
            id: box
            vertical: root.vertical
            startRadius: root.startRadius
            endRadius: root.endRadius
            flat: root.flat
            shadow: root.layerEnabled
            active: root.popupOpen
            hovered: root.isHovered
        }

        Text {
            anchors.centerIn: parent
            text: Icons.faders
            font.family: Icons.font
            font.pixelSize: BarLook.iconSize(root.moduleSize)
            color: box.ink
            opacity: 1 - inlineOsd.opacity
        }

        OsdBarInline {
            id: inlineOsd
            anchors.fill: parent
            radius: Math.max(root.startRadius, root.endRadius)
            vertical: root.vertical
            screen: root.bar ? root.bar.screen : null
            available: root.visible && !!root.bar && root.bar.reveal
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    Quickshell.execDetached(["pavucontrol"]);
                else
                    controlsPopup.toggle();
            }
        }
    }

    // A click on the OSD opens the controls popup of its screen.
    Connections {
        target: OsdService

        function onControlsRequested(screenName) {
            const mine = root.bar && root.bar.screen ? root.bar.screen.name : "";
            if (screenName === "" || mine === "" || screenName === mine)
                controlsPopup.open();
        }
    }

    ControlsPopup {
        id: controlsPopup
        anchorItem: buttonBg
        bar: root.bar
    }
}
