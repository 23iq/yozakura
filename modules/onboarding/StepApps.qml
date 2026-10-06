import QtQuick
import qs.modules.services
import qs.modules.extras

// Everyday apps from the extras catalog. On the first visit the
// recommended ones that are not installed yet come pre-checked; the
// selection is remembered (`apps`) so a revisit or resume shows it again.
// Installing queues them in the backend and the wizard moves on while
// they install.
Item {
    id: root

    property OnboardingState wizard

    readonly property var saved: wizard ? wizard.choices.apps : undefined
    // selection changes count once the remembered one is restored
    property bool _live: false

    function rememberSelection() {
        const ids = Object.keys(host.selected).filter(id => host.selected[id]);
        // an empty first selection would block the preselection to come
        if (root.wizard && (root.saved !== undefined || ids.length > 0))
            root.wizard.remember("apps", ids);
    }

    Component.onCompleted: {
        ExtrasService.load();
        if (root.saved !== undefined) {
            const sel = {};
            root.saved.forEach(id => sel[id] = true);
            host.selected = sel;
        }
        root._live = true;
        root.rememberSelection();
    }

    CatalogHost {
        id: host
        objectName: "appsCatalog"
        anchors.fill: parent
        mode: "onboarding"
        // first visit only; afterwards the remembered selection wins
        autoPreselect: root.saved === undefined
        categories: ["browsers", "chat", "games", "media", "work", "files"]
        // four per row: more of the catalog in view on small screens
        minCardWidth: 220
        sideMargin: 0
        topMargin: 0
        onSelectedChanged: {
            if (root._live)
                root.rememberSelection();
        }
    }
}
