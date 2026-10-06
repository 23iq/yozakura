import QtQuick
import qs.modules.services
import qs.modules.extras

// Everyday apps from the extras catalog: the recommended ones that are not
// installed yet come pre-checked; "Install selected" queues them in the
// backend and the wizard moves on while they install.
Item {
    id: root

    property OnboardingState wizard

    Component.onCompleted: ExtrasService.load()

    CatalogHost {
        objectName: "appsCatalog"
        anchors.fill: parent
        mode: "onboarding"
        categories: ["browsers", "chat", "games", "media", "work", "files"]
        sideMargin: 0
        topMargin: 0
    }
}
