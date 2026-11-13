import QtQuick
import qs.modules.services
import qs.modules.settings.controls
import qs.modules.settings.store

// The interface language (system.language) as picture cards: Auto (the
// detected language) and each shipped translation (translations/
// languages.json via I18n), each showing a greeting and today's date in
// that language (thumbs/LocaleThumb).
Item {
    id: root

    property var entry
    // a card of the page row: one strip of this height
    property real fillHeight: 0
    readonly property var languages: I18n.availableLanguages ?? ({})
    readonly property string detected: typeof I18n.detectSystemLanguage === "function" ? I18n.detectSystemLanguage() : "en"
    readonly property var options: [
        {
            "value": "auto",
            "label": I18n.t("language.auto_detected", root.languages[root.detected] ?? root.detected)
        }
    ].concat(Object.keys(root.languages).sort().map(code => ({
                "value": code,
                "label": root.languages[code]
            })))

    implicitHeight: cards.implicitHeight

    CardSelector {
        id: cards
        objectName: "languageCards"
        width: parent.width
        entry: ({
                "thumb": "LocaleThumb"
            })
        options: root.options
        value: SettingsStore.get("system.language") ?? "auto"
        fillHeight: root.fillHeight
        onSelected: v => SettingsStore.set("system.language", v)
    }
}
