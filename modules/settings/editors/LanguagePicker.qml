import QtQuick
import qs.modules.services
import qs.modules.settings.controls
import qs.modules.settings.store

// UI language: "Auto" (the detected system language) or one of the
// shipped translations (translations/languages.json via I18n).
Item {
    id: root

    property var entry
    readonly property var languages: I18n.availableLanguages ?? ({})
    readonly property string detected: typeof I18n.detectSystemLanguage === "function" ? I18n.detectSystemLanguage() : "en"
    readonly property var options: {
        const out = [
            {
                "value": "auto",
                "label": I18n.t("language.auto_detected", root.languages[root.detected] ?? root.detected),
                "icon": "magicWand"
            }
        ];
        Object.keys(root.languages).sort().forEach(code => {
            return out.push({
                "value": code,
                "label": root.languages[code],
                "icon": "translate"
            });
        });
        return out;
    }

    implicitHeight: selector.implicitHeight

    SelectorControl {
        id: selector

        width: parent.width
        translate: false
        options: root.options
        value: SettingsStore.get("system.language") ?? "auto"
        onSelected: v => {
            return SettingsStore.set("system.language", v);
        }
    }
}
