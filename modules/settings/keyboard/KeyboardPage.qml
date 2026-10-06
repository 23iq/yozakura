import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import "../../services/KeyboardModel.js" as KeyboardModel

// Settings > Keyboard: layouts (order, variants), how to switch, XKB options
// and key repeat. Edits go straight into the keyboard config domain;
// KeyboardService applies them to the running compositor.
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

    function save() {
        Config.saveKeyboard();
    }

    function setLayouts(list) {
        Config.keyboard.layouts = list;
        save();
    }

    function setOptions(name, on) {
        Config.keyboard.options = KeyboardModel.setOption(Array.from(Config.keyboard.options), name, on);
        save();
    }

    Component.onCompleted: KeyboardService.loadCatalog()

    Timer {
        id: slowSave
        interval: 350
        onTriggered: page.save()
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

        LayoutList {
            objectName: "layoutList"
            width: parent.width
            layouts: Config.keyboardReady ? Array.from(Config.keyboard.layouts) : []
            catalog: KeyboardService.catalog
            activeIndex: KeyboardService.active.index
            showIndicator: Config.keyboardReady && Config.keyboard.showIndicator
            onChanged: list => page.setLayouts(list)
            onIndicatorToggled: v => {
                Config.keyboard.showIndicator = v;
                page.save();
            }
        }

        KeyboardOptions {
            objectName: "optionsCard"
            width: parent.width
            catalog: KeyboardService.catalog
            switchBind: Config.keyboardReady ? Config.keyboard.switchBind : "alt_shift"
            options: Config.keyboardReady ? Array.from(Config.keyboard.options) : []
            onBindPicked: bind => {
                Config.keyboard.switchBind = bind;
                page.save();
            }
            onOptionToggled: (name, on) => page.setOptions(name, on)
        }

        TypingCard {
            objectName: "typingCard"
            width: parent.width
            repeatRate: Config.keyboardReady ? Config.keyboard.repeatRate : 25
            repeatDelay: Config.keyboardReady ? Config.keyboard.repeatDelay : 600
            onRateMoved: v => {
                Config.keyboard.repeatRate = v;
                slowSave.restart();
            }
            onDelayMoved: v => {
                Config.keyboard.repeatDelay = v;
                slowSave.restart();
            }
        }
    }
}
