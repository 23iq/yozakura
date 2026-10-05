pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.editors

// Create special workspaces (Hyprland scratchpads): quick templates (Chat,
// Music, Dev, Notes, Custom = "Special N"), then rename, icon, binds and
// apps per special: the same editor as Settings > Special workspaces.
// Optional: Continue without adding any (new installs have none).
Item {
    id: root

    property OnboardingState wizard

    Flickable {
        id: flick
        objectName: "specialsFlick"
        anchors.fill: parent
        contentWidth: width
        contentHeight: editor.implicitHeight + 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: flick.contentHeight > flick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        SpecialsEditor {
            id: editor
            objectName: "specialsEditor"
            width: flick.width - 16
        }
    }
}
