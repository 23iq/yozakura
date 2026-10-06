import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import "../../services/KeyboardModel.js" as KeyboardModel

// Settings > Keyboard: layouts (order, variants), how to switch, XKB options
// and key repeat. Until the user changes something here the compositor's own
// settings are shown (and stay in effect); every edit goes through
// KeyboardService.edit(), which takes them over first and applies the change.
Flickable {
    id: page

    required property var category

    contentWidth: width
    contentHeight: column.implicitHeight + 120
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
    }

    // SettingsShell reveal() hook (search jumps): one page, nothing to scroll to.
    function reveal(section, entry) {
    }

    readonly property var kb: KeyboardService.effective
    // Edits build on the values shown: wait until they are known, and until
    // an unreadable compositor setup was explicitly taken over
    readonly property bool editable: KeyboardService.known && !KeyboardService.unreadable
    // Slider values not saved yet (-1: none); saved together after 350 ms
    property int pendingRate: -1
    property int pendingDelay: -1

    function saveRepeat() {
        const patch = {};
        if (page.pendingRate >= 0)
            patch.repeatRate = page.pendingRate;
        if (page.pendingDelay >= 0)
            patch.repeatDelay = page.pendingDelay;
        page.pendingRate = -1;
        page.pendingDelay = -1;
        if (Object.keys(patch).length > 0)
            KeyboardService.edit(patch);
    }

    function setLayouts(list) {
        KeyboardService.edit({
            "layouts": list
        });
    }

    function setOptions(name, on) {
        KeyboardService.edit({
            "options": KeyboardModel.setOption(page.kb.options, name, on)
        });
    }

    Component.onCompleted: {
        KeyboardService.loadCatalog();
        KeyboardService.refreshCurrent();
    }

    Component.onDestruction: page.saveRepeat()

    Timer {
        id: repeatSave
        interval: 350
        onTriggered: page.saveRepeat()
    }

    Column {
        id: column
        width: Math.min(page.width - 64, 820)
        x: (page.width - width) / 2
        y: 36
        spacing: 22

        PageHeader {
            width: parent.width
            category: page.category
        }

        UnmanagedNote {
            objectName: "unmanagedNote"
            width: parent.width
            visible: Config.keyboardReady && !KeyboardService.managed
        }

        LayoutList {
            objectName: "layoutList"
            width: parent.width
            enabled: page.editable
            layouts: page.kb.layouts
            catalog: KeyboardService.catalog
            activeIndex: KeyboardService.active.index
            showIndicator: Config.keyboardReady && Config.keyboard.showIndicator
            onChanged: list => page.setLayouts(list)
            onIndicatorToggled: v => KeyboardService.edit({
                    "showIndicator": v
                })
        }

        KeyboardOptions {
            objectName: "optionsCard"
            width: parent.width
            enabled: page.editable
            catalog: KeyboardService.catalog
            switchBind: page.kb.switchBind
            options: page.kb.options
            onBindPicked: bind => KeyboardService.edit({
                    "switchBind": bind
                })
            onOptionToggled: (name, on) => page.setOptions(name, on)
        }

        TypingCard {
            objectName: "typingCard"
            width: parent.width
            enabled: page.editable
            repeatRate: page.pendingRate >= 0 ? page.pendingRate : page.kb.repeatRate
            repeatDelay: page.pendingDelay >= 0 ? page.pendingDelay : page.kb.repeatDelay
            onRateMoved: v => {
                page.pendingRate = v;
                repeatSave.restart();
            }
            onDelayMoved: v => {
                page.pendingDelay = v;
                repeatSave.restart();
            }
        }
    }
}
