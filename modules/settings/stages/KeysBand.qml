pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.keybinds
import qs.modules.components.kit
import "KeyDeck.js" as Deck
import "../../keybinds/KeyNames.js" as KeyNames

// The Shortcuts tab's band (list form): a keyboard drawn from keycaps with
// the keys of the shortcut you opened in the list lit (the cheatsheet's
// while none is open), and what it does beside it. Recording new keys for
// it lights them as soon as they are saved.
Stage {
    id: band
    objectName: "keysBand"

    readonly property var bind: {
        KeybindsStore.rows;
        const open = KeybindsStore.expandedUid !== "" ? KeybindsStore.row(KeybindsStore.expandedUid) : null;
        return open || KeybindsStore.row("core:system.keybinds");
    }
    readonly property var combo: band.bind && band.bind.keys && band.bind.keys.length > 0 ? band.bind.keys[0] : null

    stageHeight: Space.px(150)

    Mark {
        anchors.fill: parent
        radius: 0
        color: Qt.alpha(Colors.background, 0.55)
    }

    KeyDeck {
        id: deck
        objectName: "keysDeck"
        x: Space.xl
        y: Space.m
        width: Math.min(parent.width * 0.62, (parent.height - Space.m * 2) * Deck.UNITS / 5)
        height: parent.height - Space.m * 2
        lit: Deck.lit(band.combo)
    }

    Column {
        anchors.left: deck.right
        anchors.leftMargin: Space.xl
        anchors.right: parent.right
        anchors.rightMargin: Space.xl
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.xs
        KitText {
            objectName: "keysCombo"
            width: parent.width
            role: "title"
            color: Type.accent
            elide: Text.ElideRight
            text: band.combo ? KeyNames.comboText(band.combo.modifiers, band.combo.key, "Super") : ""
        }
        KitText {
            objectName: "keysAction"
            width: parent.width
            role: "body"
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            text: band.bind ? KeybindsStore.title(band.bind) : I18n.t("prefs.keys.pick")
        }
    }
}
