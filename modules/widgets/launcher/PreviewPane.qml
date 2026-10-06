import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.config
import "previews/PreviewRegistry.js" as PreviewRegistry

// Preview beside the results (layout.launcher.preview). The selected result
// only reaches the preview after a short pause and the component loads
// asynchronously, so moving the selection or typing never waits on it.
// Which results have one: previews/PreviewRegistry.js.
StyledRect {
    id: pane

    property var selection: null
    readonly property var spec: PreviewRegistry.previewFor(selection)
    // True when the selected result has a preview (the host opens the pane).
    readonly property bool available: spec !== null

    // Debounced copy of `selection`: what the loader actually shows.
    property var shown: null

    variant: "pane"
    radius: Styling.radius(4)
    clip: true

    onSelectionChanged: {
        if (selection === null)
            shown = null;
        else
            settle.restart();
    }

    Timer {
        id: settle
        interval: Motion.delay + 40
        onTriggered: pane.shown = pane.selection
    }

    Loader {
        id: loader
        anchors.fill: parent
        anchors.margins: Metrics.padding
        asynchronous: true
        active: pane.shown !== null && PreviewRegistry.previewFor(pane.shown) !== null
        source: active ? Qt.resolvedUrl(PreviewRegistry.previewFor(pane.shown).file) : ""
        opacity: status === Loader.Ready ? 1 : 0
        Behavior on opacity {
            enabled: Motion.enter.duration > 0
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
            }
        }
        onLoaded: item.result = pane.shown
        Connections {
            target: pane
            function onShownChanged() {
                if (loader.item && pane.shown)
                    loader.item.result = pane.shown;
            }
        }
    }
}
