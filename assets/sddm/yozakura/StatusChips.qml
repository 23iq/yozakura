import QtQuick

// Status chips (user, keyboard layout, session, power) and their menus, in
// the active style's chip look. Shown on the primary screen only.
Item {
    id: chrome

    required property Item greeter
    opacity: chrome.greeter.reveal

    // User chip (+ layout) on the left; session and power on the right.
    Row {
        id: leftChips
        spacing: 8
        x: chrome.greeter.edgeMargin * 0.75
        y: chrome.greeter.atTop ? parent.height - height - chrome.greeter.edgeMargin * 0.75 : chrome.greeter.edgeMargin * 0.75

        Chip {
            id: userChip
            look: chrome.greeter.style
            label: chrome.greeter.userName
            glyphFont: chrome.greeter.iconFont
            caret: chrome.greeter.userCount > 1
            caretGlyph: chrome.greeter.iconCaretDown
            active: chrome.greeter.openMenu === "user"
            visible: chrome.greeter.userName !== ""
            onClicked: {
                if (chrome.greeter.userCount > 1)
                    chrome.greeter.openMenu = chrome.greeter.openMenu === "user" ? "" : "user";
                else
                    chrome.greeter.focusPassword();
            }
            leading: Avatar {
                greeter: chrome.greeter
                width: 28
                height: 28
                ink: userChip.ink
            }
        }

        Chip {
            id: layoutChip
            look: chrome.greeter.style
            visible: chrome.greeter.layouts.length > 1
            glyph: chrome.greeter.iconKeyboard
            glyphFont: chrome.greeter.iconFont
            label: {
                var l = chrome.greeter.layouts.length > 1 ? chrome.greeter.layouts[keyboard.currentLayout] : null;
                return l ? (l.shortName || "").toUpperCase() : "";
            }
            active: chrome.greeter.openMenu === "layout"
            onClicked: chrome.greeter.openMenu = chrome.greeter.openMenu === "layout" ? "" : "layout"
        }
    }

    Row {
        id: rightChips
        spacing: 8
        x: parent.width - width - chrome.greeter.edgeMargin * 0.75
        y: leftChips.y

        Chip {
            look: chrome.greeter.style
            visible: chrome.greeter.sessionCount > 0
            glyph: chrome.greeter.iconSession
            glyphFont: chrome.greeter.iconFont
            label: chrome.greeter.currentSession ? chrome.greeter.currentSession.sName : ""
            caret: chrome.greeter.sessionCount > 1
            caretGlyph: chrome.greeter.iconCaretDown
            active: chrome.greeter.openMenu === "session"
            onClicked: chrome.greeter.openMenu = chrome.greeter.openMenu === "session" ? "" : "session"
        }
        Chip {
            look: chrome.greeter.style
            visible: sddm.canSuspend
            width: 36
            glyph: chrome.greeter.iconSuspend
            glyphFont: chrome.greeter.iconFont
            onClicked: sddm.suspend()
        }
        Chip {
            look: chrome.greeter.style
            enabled: sddm.canReboot
            opacity: enabled ? 1 : 0.45
            width: 36
            glyph: chrome.greeter.iconReboot
            glyphFont: chrome.greeter.iconFont
            onClicked: sddm.reboot()
        }
        Chip {
            look: chrome.greeter.style
            enabled: sddm.canPowerOff
            opacity: enabled ? 1 : 0.45
            width: 36
            glyph: chrome.greeter.iconShutdown
            glyphFont: chrome.greeter.iconFont
            glyphColor: chrome.greeter.style ? chrome.greeter.style.error : pal.error
            onClicked: sddm.powerOff()
        }
    }

    // Menus open away from the screen edge the chips sit on.
    MenuPopup {
        z: 20
        look: chrome.greeter.style
        visible: chrome.greeter.openMenu === "session"
        entries: visible ? chrome.greeter.sessionNames() : []
        currentIndex: chrome.greeter.sessionIndex
        x: rightChips.x + rightChips.width - width
        y: chrome.greeter.atTop ? rightChips.y - height - 8 : rightChips.y + rightChips.height + 8
        onPicked: index => {
            chrome.greeter.sessionIndex = index;
            chrome.greeter.openMenu = "";
            chrome.greeter.focusPassword();
        }
    }
    MenuPopup {
        z: 20
        look: chrome.greeter.style
        visible: chrome.greeter.openMenu === "user"
        entries: visible ? chrome.greeter.userNames() : []
        currentIndex: chrome.greeter.userIndex
        x: leftChips.x
        y: chrome.greeter.atTop ? leftChips.y - height - 8 : leftChips.y + leftChips.height + 8
        onPicked: index => {
            chrome.greeter.userIndex = index;
            chrome.greeter.message = "";
            if (chrome.greeter.passwordField)
                chrome.greeter.passwordField.text = "";
            chrome.greeter.openMenu = "";
            chrome.greeter.focusPassword();
        }
    }
    MenuPopup {
        z: 20
        look: chrome.greeter.style
        visible: chrome.greeter.openMenu === "layout"
        entries: visible ? chrome.greeter.layoutNames() : []
        currentIndex: typeof keyboard !== "undefined" && keyboard ? keyboard.currentLayout : -1
        x: leftChips.x + (userChip.visible ? userChip.width + leftChips.spacing : 0)
        y: chrome.greeter.atTop ? leftChips.y - height - 8 : leftChips.y + leftChips.height + 8
        onPicked: index => {
            keyboard.currentLayout = index;
            chrome.greeter.openMenu = "";
            chrome.greeter.focusPassword();
        }
    }
}
