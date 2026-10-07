import QtQuick
import qs.modules.components
import qs.modules.theme

// The themed panel of a SurfaceHost. Swallows clicks so they never reach the
// host's click-outside scrim; `slot` receives the view, and Escape from the
// view bubbles up to it.
StyledRect {
    id: root

    readonly property alias slot: slotItem
    property int padding: Metrics.padding

    signal escapePressed

    variant: "bg"
    radius: Styling.radius(20)
    // The rect\'s own shadow (also drawn by a corner style\'s mask)
    enableShadow: true

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    Item {
        id: slotItem
        anchors.fill: parent
        anchors.margins: root.padding
        Keys.onEscapePressed: event => {
            root.escapePressed();
            event.accepted = true;
        }
    }
}
