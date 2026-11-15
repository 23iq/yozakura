import QtQuick
import qs.modules.components.kit
import qs.modules.services
import qs.modules.settings.store
import "presets/PresetModel.js" as PresetModel
import "Ui.js" as Ui

// The preset overlays of the settings window (SettingsShell): the edit
// banner along the top, the trial pill, the toast, the active preset's
// changes sheet and the name dialog, each a Loader by URL, asynchronous,
// once `ready` (home showed its first frame, or a page is open): none is
// on the first frame, nor is its compile. `presetAction(id)` runs the
// active preset's actions (home footer, changes sheet, toast).
Item {
    id: overlays

    // load them (after the first frame)
    property bool ready: false
    // the home search index (the changes sheet names rows with it)
    property var index: []
    // The active preset's changes sheet is open (home footer, toast).
    property bool changesOpen: false
    // the edit banner's height: home and the page start under it
    readonly property real bannerHeight: editBanner.height

    // a row of the changes sheet asks for its setting
    signal navigate(string categoryId, string sectionId, string entryId)

    function presetAction(id) {
        const toast = (ok, message, undo) => PresetStudio.notify(message, undo ? "save:" + undo : "");
        if (id === "save")
            PresetStudio.afterFlush(() => PresetStatusService.save(toast));
        else if (id === "saveAs")
            Ui.invoke(saveAsDialog.item, "ask", [I18n.t("presets.status.dialog_save_as"), PresetModel.uniqueName(PresetStudio.presets, PresetStatusService.suggestedName()), I18n.t("prefs.presets.save"), "", n => PresetStudio.afterFlush(() => PresetStatusService.saveAs(n, toast))]);
        else if (id === "changes")
            overlays.changesOpen = true;
        else if (id === "revert")
            PresetStatusService.revert(toast);
    }

    Loader {
        id: editBanner
        width: parent.width
        active: overlays.ready
        asynchronous: true
        source: Qt.resolvedUrl("presets/PresetEditBanner.qml")
    }

    Loader {
        anchors.horizontalCenter: parent.horizontalCenter
        y: editBanner.height + Space.l
        active: overlays.ready
        asynchronous: true
        source: Qt.resolvedUrl("presets/PresetTrialPill.qml")
    }

    Loader {
        anchors.left: parent.left
        anchors.leftMargin: Space.xl
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Space.xl
        active: overlays.ready
        asynchronous: true
        source: Qt.resolvedUrl("presets/PresetToast.qml")
        onLoaded: Ui.on(item, "detailsRequested", () => overlays.presetAction("changes"))
    }

    Loader {
        id: changesSheet
        anchors.fill: parent
        active: overlays.ready || overlays.changesOpen
        asynchronous: !overlays.changesOpen
        source: Qt.resolvedUrl("presets/PresetChangesSheet.qml")
        onLoaded: {
            item.open = Qt.binding(() => overlays.changesOpen);
            item.index = Qt.binding(() => overlays.index);
            Ui.on(item, "closed", () => overlays.changesOpen = false);
            Ui.on(item, "actionRequested", id => overlays.presetAction(id));
            Ui.on(item, "navigate", (c, sec, e) => overlays.navigate(c, sec, e));
        }
    }

    Loader {
        id: saveAsDialog
        anchors.fill: parent
        active: overlays.ready
        asynchronous: true
        source: Qt.resolvedUrl("presets/PresetNameDialog.qml")
    }
}
