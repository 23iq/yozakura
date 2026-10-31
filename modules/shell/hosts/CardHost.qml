import QtQuick
import Quickshell
import qs.modules.shell
import qs.modules.theme
import qs.modules.components.kit

// A small floating card beside the bar: EdgeService.cardRect puts it in the
// corner at the end of the bar's edge, inside the work area, so it never
// sits under a bar, dock or notch, on any edge. Shows the notch's auto
// panels off the notch (PanelSurfaces) and the AI quick ask
// (layout.aiquick.host "card", HostedSurfaces). The kit's floating Surface,
// gliding in from its edge (Motion.glide). Modal (the default): Escape and a
// click outside ask to close (SurfaceHost). Not modal: no focus, and input
// only reaches the card; the rest of the screen stays usable.
SurfaceHost {
    id: root

    hostName: "card"
    slot: slotItem
    enterMotion: Motion.glide
    exitMotion: Motion.glide

    // Padding around the view (the notch panels bring their own: 0)
    property int padding: 0
    // Width for views without an implicit width (notch panels fill theirs)
    property int preferredWidth: 0

    readonly property var area: EdgeService.cardRect(root.screen, {
        "w": Math.max(root.preferredWidth, root.view ? root.view.implicitWidth : 0) + root.padding * 2,
        "h": (root.view ? root.view.implicitHeight : 0) + root.padding * 2
    }, Space.m)
    // Offset toward the edge it glides in from
    readonly property real _slide: Space.l * (1 - root.progress)
    readonly property bool _sideways: root.area.from === "left" || root.area.from === "right"
    readonly property int _sign: root.area.from === "bottom" || root.area.from === "right" ? 1 : -1

    mask: Region {
        item: root.modal ? backdrop : card
    }

    HostBackdrop {
        id: backdrop
        anchors.fill: parent
        // A card never dims the screen; the area only catches the click
        strength: 0
        progress: root.progress
        enabled: root.modal
        onClicked: root.requestClose()
    }

    Surface {
        id: card
        objectName: "cardFrame"
        floating: true
        padding: 0
        x: root.area.x + (root._sideways ? root._sign * root._slide : 0)
        y: root.area.y + (root._sideways ? 0 : root._sign * root._slide)
        width: root.area.w
        height: root.area.h
        opacity: Math.min(1, root.progress)

        Behavior on height {
            enabled: root.progress === 1 && Motion.glide.duration > 0
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }

        // Clicks on the card never reach the backdrop
        MouseArea {
            width: card.width
            height: card.height
            acceptedButtons: Qt.AllButtons
        }

        Item {
            id: slotItem
            x: root.padding
            y: root.padding
            width: Math.max(0, card.width - root.padding * 2)
            height: Math.max(0, card.height - root.padding * 2)
            Keys.onEscapePressed: event => {
                root.requestClose();
                event.accepted = true;
            }
        }
    }
}
