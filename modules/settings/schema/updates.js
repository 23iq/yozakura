.pragma library

// Updates & OCR: background update checks and the tesseract languages used
// by the OCR tool. Entry format: see modules/settings/AGENTS.md.

var OCR_KEYS = ["eng", "spa", "lat", "jpn", "chi_sim", "chi_tra", "kor", "rus"];

var category = {
    "id": "updates",
    "icon": "downloadSimple",
    "title": "prefs.cat.updates",
    "description": "prefs.cat.updates.desc",
    "keywords": "updates version release changelog ocr text recognition tesseract languages",
    "sections": [
        {
            "id": "updates",
            "title": "prefs.updates.section.updates",
            "entries": [
                {
                    "id": "updates.status",
                    "type": "custom",
                    "component": "UpdatesStatus",
                    "resettable": false,
                    "label": "prefs.updates.status",
                    "description": "prefs.updates.status.desc",
                    "keywords": "version check now changelog release about"
                },
                {
                    "key": "system.updateServiceEnabled",
                    "type": "toggle",
                    "label": "shell.system.update_service",
                    "description": "prefs.updates.service.desc",
                    "keywords": "updates check background notify new version"
                }
            ]
        },
        {
            "id": "ocr",
            "title": "shell.system.ocr_languages",
            "entries": [
                {
                    "id": "system.ocr",
                    "type": "custom",
                    "component": "OcrLanguages",
                    "keys": OCR_KEYS.map(function (k) {
                        return "system.ocr." + k;
                    }),
                    "label": "shell.system.ocr_languages",
                    "description": "prefs.updates.ocr.desc",
                    "keywords": "ocr text recognition tesseract languages english spanish latin japanese chinese korean russian"
                }
            ]
        }
    ]
};
