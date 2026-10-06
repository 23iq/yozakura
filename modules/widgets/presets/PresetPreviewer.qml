import QtQuick
import qs.modules.settings.store
import "PreviewQueue.js" as PreviewQueue

// Live preview for the preset switcher: hover(card) previews the card after
// `dwell` ms of staying on it (`preset apply --preview`), keep(card) applies
// it for real, revert() restores the look from before (also on destruction,
// so a popup closed any way never leaves a preview behind).
Item {
    id: root

    property int dwell: 180
    // (args, cb) running `<app> preset <args>`
    property var run: PresetStudio.run
    property string previewed: ""

    property var _queue: null
    property var _wanted: null

    function queue() {
        if (!root._queue)
            root._queue = PreviewQueue.create(root.run);
        return root._queue;
    }

    function hover(card) {
        if (!card || card.key === root.previewed && !dwellTimer.running)
            return;
        root._wanted = card;
        dwellTimer.restart();
    }

    function keep(card) {
        dwellTimer.stop();
        if (card)
            root.queue().keep(card.apply);
    }

    function revert() {
        dwellTimer.stop();
        root.queue().revert();
        root.previewed = "";
    }

    Timer {
        id: dwellTimer
        interval: root.dwell
        onTriggered: {
            const card = root._wanted;
            if (!card || card.key === root.previewed)
                return;
            root.previewed = card.key;
            root.queue().preview(card.preview);
        }
    }

    Component.onDestruction: root.revert()
}
