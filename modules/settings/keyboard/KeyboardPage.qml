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
            enabled: KeyboardService.known
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
            enabled: KeyboardService.known
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
            enabled: KeyboardService.known
            repeatRate: page.kb.repeatRate
            repeatDelay: page.kb.repeatDelay
            onRateMoved: v => KeyboardService.edit({
                    "repeatRate": v
                })
            onDelayMoved: v => KeyboardService.edit({
                    "repeatDelay": v
                })
        }
    }
}
