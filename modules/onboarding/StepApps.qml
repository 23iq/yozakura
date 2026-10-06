import QtQuick
import qs.modules.services
import qs.modules.extras
import "../extras/ExtrasModel.js" as ExtrasModel

// Everyday apps from the extras catalog. On the first visit the
// recommended ones that are not installed yet come pre-checked; the
// selection is remembered (`apps`) so a revisit or resume shows it again.
// Installing queues them in the backend and the wizard moves on while
// they install; Continue / Enter with picks left queues them too (after
// the multilib consent when one is needed), so a pick is never dropped.
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

    // Continue with picks: queue them, go on once queued (or the consent
    // was declined); an error keeps the wizard here to show it.
    property bool _leaving: false

    function leave() {
        const ids = ExtrasModel.selectedIds(ExtrasService.catalog, ExtrasService.status, ExtrasService.progress, host.selected);
        if (ids.length === 0 || ExtrasService.offline)
            return true;
        root._leaving = true;
        ExtrasService.install(ids, false);
        return false;
    }

    function _goOn() {
        if (!root._leaving)
            return;
        root._leaving = false;
        if (root.wizard)
            root.wizard.advance();
    }

    Connections {
        target: ExtrasService
        function onQueued() {
            root._goOn();
        }
        function onConfirmChanged() {
            // declined (an accepted one ends in queued, right after)
            if (!ExtrasService.confirm)
                Qt.callLater(root._goOn);
        }
        function onErrorChanged() {
            if (ExtrasService.error !== "")
                root._leaving = false;
        }
        function onUnavailableChanged() {
            if (ExtrasService.unavailable)
                root._leaving = false;
        }
    }

    Component.onCompleted: {
        if (root.wizard)
            root.wizard.leaveGuard = root.leave;
        ExtrasService.load();
        if (root.saved !== undefined) {
            // installed or installing meanwhile: no longer a pick
            const sel = {};
            root.saved.filter(id => !["installed", "installing"].includes(ExtrasService.cardState(id))).forEach(id => sel[id] = true);
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
