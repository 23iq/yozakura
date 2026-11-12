pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "Plural.js" as Plural

Singleton {
    id: root

    readonly property string configLanguage: Config.system?.language ?? "auto"
    property string resolvedLanguage: "en"
    // One lookup table: the selected language over the English fallback
    // (mergeTables), so a non-English session keeps a single dictionary.
    property var table: ({})
    property var availableLanguages: ({})
    property bool ready: false
    // Bumped after every successful load. t() reads it so every binding which
    // calls t() re-evaluates after a language change.
    property int revision: 0

    function humanize(key) {
        const segment = key.substring(key.lastIndexOf(".") + 1).replace(/_/g, " ");
        return segment.charAt(0).toUpperCase() + segment.slice(1);
    }

    function t(key) {
        const currentRevision = root.revision;
        let str = root.table[key] ?? root.humanize(key);
        for (let i = 1; i < arguments.length; i++)
            str = str.replace("%" + i, arguments[i]);
        return str;
    }

    // Count-dependent text: `<key>.<category>` (one/few/many/other for the
    // current language), else `<key>.other`, else `<key>`; %1 is the count.
    function tn(key, n) {
        const cat = Plural.category(root.resolvedLanguage, n);
        const k = [key + "." + cat, key + ".other", key].find(c => root.has(c)) ?? key;
        return root.t(k, n);
    }

    // A translation exists for key (current language or the English
    // fallback), so t() will not humanize it.
    function has(key) {
        return root.table[key] !== undefined;
    }

    // `strings` over `fallback`, built in `fallback` (a freshly parsed object
    // the caller gives up). A null/undefined entry of `strings` keeps the
    // fallback text; t() and has() answer exactly as with two lookups.
    function mergeTables(fallback, strings) {
        for (const key of Object.keys(strings)) {
            if (key === "__proto__")
                continue;
            const value = strings[key];
            if ((value !== null && value !== undefined) || fallback[key] === undefined)
                fallback[key] = value;
        }
        return fallback;
    }

    function detectSystemLanguage() {
        const sources = [
            Qt.locale().name,
            Quickshell.env("LC_MESSAGES"),
            Quickshell.env("LC_ALL"),
            Quickshell.env("LANG")
        ];
        for (const src of sources) {
            if (src && src.length >= 2) {
                const code = src.substring(0, 2).toLowerCase();
                if (code !== "c" && code !== "po")
                    return code;
            }
        }
        return "en";
    }

    function resolveLanguage() {
        const lang = root.configLanguage === "auto"
            ? detectSystemLanguage()
            : root.configLanguage;

        if (root.availableLanguages[lang])
            return lang;
        return "en";
    }

    FileView {
        id: languagesLoader
        path: Qt.resolvedUrl("../../translations/languages.json")
        blockLoading: true
    }

    FileView {
        id: fallbackLoader
        path: Qt.resolvedUrl("../../translations/en.json")
        blockLoading: true
    }

    FileView {
        id: langLoader
        path: root.resolvedLanguage !== "en"
              ? Qt.resolvedUrl("../../translations/" + root.resolvedLanguage + ".json")
              : ""
        blockLoading: true
    }

    // blockLoading takes effect on an explicit text() call. Read the files
    // here so translations exist before the first UI binding evaluates.
    function loadAll() {
        try {
            root.availableLanguages = JSON.parse(languagesLoader.text());
        } catch (e) {
            console.warn("I18n: failed to parse languages.json:", e);
            root.availableLanguages = { "en": "English" };
        }

        let fallback = ({});
        try {
            fallback = JSON.parse(fallbackLoader.text());
        } catch (e) {
            console.warn("I18n: failed to parse en.json:", e);
        }
        if (fallback === null || typeof fallback !== "object")
            fallback = ({});
        const ready = Object.keys(fallback).length > 0;

        root.resolvedLanguage = root.resolveLanguage();

        let table = fallback;
        if (root.resolvedLanguage !== "en") {
            try {
                const strings = JSON.parse(langLoader.text());
                if (strings !== null && typeof strings === "object")
                    table = root.mergeTables(fallback, strings);
            } catch (e) {
                console.warn("I18n: failed to parse " + root.resolvedLanguage + ".json:", e);
            }
        }

        root.table = table;
        root.ready = ready;
        root.revision++;
    }

    Component.onCompleted: root.loadAll()
    onConfigLanguageChanged: root.loadAll()
}
