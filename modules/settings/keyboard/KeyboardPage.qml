pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.editors
import qs.modules.settings.stages
import "../../services/KeyboardModel.js" as KeyboardModel
import "../../keybinds/KeyNames.js" as KeyNames
import "../stages/KeyDeck.js" as Deck
import qs.modules.components.kit

// Settings > Keyboard, fitted like a converted page (modules/settings/
// AGENTS.md, PAGE COMPOSITION): the hero is a keyboard drawn from keycaps
// with the layout in use on its space bar and the keys that switch layouts
// lit; type in the field under it and the keys you hold light up too.
// Then one row of cards: your layouts (order, variants, add), how to
// switch and the common XKB options, key repeat. Until the user changes
// something here the compositor's own settings are shown (and stay in
// effect); every edit goes through KeyboardService.edit(), which takes
// them over first and applies the change.
FittedFrame {
    id: page

    required property var category

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
    // keys held in the try field (KeyDeck ids)
    property var held: []

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

    // a Qt key event -> the KeyDeck id it lights ("" for none)
    function deckKey(key, text) {
        const mod = KeyNames.qtModifierKey(key);
        if (mod)
            return mod;
        const k = KeyNames.keyFromQt(key, text);
        return k ? KeyNames.normalizeKey(k) : "";
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

    // ---- the hero: the keyboard, the try field, what needs saying ---------
    Item {
        id: hero
        readonly property bool fittedHero: true
        x: page.margin
        y: Space.s
        width: page.width - page.margin * 2
        height: page.heroH

        RectangularShadow {
            anchors.fill: stage
            radius: Look.radius("surface", stage.height)
            offset: Qt.vector2d(0, Space.l)
            blur: Space.xxl * 2
            color: Qt.alpha(Colors.shadow, 0.55)
        }
        Stage {
            id: stage
            objectName: "keyboardStage"
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(hero.width, hero.height * 16 / 9)
            height: hero.height

            Mark {
                anchors.fill: parent
                radius: 0
                color: Qt.alpha(Colors.background, 0.55)
            }
            KeyDeck {
                id: deck
                objectName: "keyboardDeck"
                x: Space.xl
                y: Space.l
                width: parent.width - Space.xl * 2
                height: parent.height - tryField.height - Space.l * 3
                badge: KeyboardService.shortLabel
                lit: Deck.switchKeys(page.kb.switchBind).concat(page.held)
            }
            TryTypingField {
                id: tryField
                objectName: "tryField"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Space.l
                width: Math.min(parent.width - Space.xl * 2, Space.px(520))
                onKeyDown: (key, text, mods) => {
                    const id = page.deckKey(key, text);
                    if (id !== "" && page.held.indexOf(id) < 0)
                        page.held = page.held.concat([id]);
                }
                onKeyUp: (key, text, mods) => {
                    const id = page.deckKey(key, text);
                    page.held = page.held.filter(k => k !== id);
                }
                onActiveFocusChanged: if (!activeFocus)
                    page.held = []
            }

            // problems first, over the keyboard
            Column {
                x: Space.l
                y: Space.l
                width: parent.width - Space.l * 2
                spacing: Space.s
                KeyboardStatus {
                    width: parent.width
                }
                UnmanagedNote {
                    objectName: "unmanagedNote"
                    width: parent.width
                    visible: Config.keyboardReady && !KeyboardService.managed && !KeyboardService.readFailed
                }
            }
        }
    }

    KitText {
        objectName: "heroHint"
        x: page.margin
        y: hero.y + hero.height + Space.s
        width: page.width - page.margin * 2
        horizontalAlignment: Text.AlignHCenter
        role: "secondary"
        text: I18n.t("prefs.keyboard.hero_hint")
    }

    // ---- the row ------------------------------------------------------------
    Row {
        id: row
        objectName: "keyboardRow"
        x: page.margin
        y: page.height - page.rowH - page.pad
        width: page.width - page.margin * 2
        height: page.rowH
        spacing: page.gap
        readonly property real unitW: (row.width - row.spacing * 2) / 3.2

        PageCard {
            width: row.unitW * 1.2
            height: row.height
            title: I18n.t("prefs.keyboard.layouts")
            value: KeyboardService.shortLabel
            CardScroll {
                anchors.fill: parent
                LayoutList {
                    objectName: "layoutList"
                    width: parent.width
                    headless: true
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
            }
        }

        PageCard {
            width: row.unitW
            height: row.height
            title: I18n.t("prefs.keyboard.switching")
            CardScroll {
                anchors.fill: parent
                KeyboardOptions {
                    objectName: "optionsCard"
                    width: parent.width
                    headless: true
                    enabled: page.editable
                    catalog: KeyboardService.catalog
                    switchBind: page.kb.switchBind
                    options: page.kb.options
                    onBindPicked: bind => KeyboardService.edit({
                            "switchBind": bind
                        })
                    onOptionToggled: (name, on) => page.setOptions(name, on)
                }
            }
        }

        PageCard {
            width: row.unitW
            height: row.height
            title: I18n.t("prefs.keyboard.typing")
            CardScroll {
                anchors.fill: parent
                TypingCard {
                    objectName: "typingCard"
                    width: parent.width
                    headless: true
                    showTry: false
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
    }
}
