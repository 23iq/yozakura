import QtQuick
import qs.modules.settings.controls
import qs.modules.settings.store

// OCR (tesseract) languages as chips; each one is a boolean key
// system.ocr.<code> (entry.keys).
Item {
    id: root

    property var entry
    readonly property var codes: (entry && entry.keys ? entry.keys : []).map(k => {
        return k.split(".").pop();
    })
    readonly property var labels: ({
            "eng": "shell.system.ocr_english",
            "spa": "shell.system.ocr_spanish",
            "lat": "shell.system.ocr_latin",
            "jpn": "shell.system.ocr_japanese",
            "chi_sim": "shell.system.ocr_chinese_simplified",
            "chi_tra": "shell.system.ocr_chinese_traditional",
            "kor": "shell.system.ocr_korean",
            "rus": "shell.system.ocr_russian"
        })
    readonly property var selected: codes.filter(c => {
        return !!SettingsStore.get("system.ocr." + c);
    })

    implicitHeight: chips.implicitHeight

    ChipsControl {
        id: chips

        width: parent.width
        options: root.codes.map(c => {
            return ({
                    "value": c,
                    "label": root.labels[c] ?? c
                });
        })
        values: root.selected
        onChanged: v => {
            root.codes.forEach(c => {
                return SettingsStore.set("system.ocr." + c, v.indexOf(c) !== -1);
            });
        }
    }
}
