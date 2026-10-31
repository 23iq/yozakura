import QtQuick
import qs.modules.components.kit

// A kit Chip the keyboard reaches: Tab focuses it (focus ring), Enter /
// Space click it. The wizard's text buttons (Back / Continue, skip, peek).
// Candidate for the kit (Chip.focusable, like IconButton.focusable).
Chip {
    id: root

    activeFocusOnTab: true
    highlighted: root.activeFocus && FocusState.keyboard

    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    FocusRing {
        shown: root.activeFocus
        radius: root.radius + Space.stroke
    }
}
