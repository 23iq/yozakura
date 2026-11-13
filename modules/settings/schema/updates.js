.pragma library

// Updates & OCR: the stage is the update state with its one action and the
// channels as lanes (UpdatesStage); the row: background checks and the
// channel, and the tesseract languages used by the OCR tool. Entry format:
// see modules/settings/AGENTS.md.

var OCR_KEYS = ["eng", "spa", "lat", "jpn", "chi_sim", "chi_tra", "kor", "rus"];

var category = {
    "id": "updates",
    "icon": "downloadSimple",
    "title": "prefs.cat.updates",
    "description": "prefs.cat.updates.desc",
    "keywords": "updates version release changelog ocr text recognition tesseract languages",
    "row": ["updates", "ocr"],
    "sections": [
        {
            "id": "updates",
            "title": "prefs.updates.section.updates",
            "entries": [
                {
                    "key": "system.updateServiceEnabled",
                    "type": "toggle",
                    "label": "prefs.updates.service",
                    "description": "prefs.updates.service.desc",
                    "keywords": "updates check background notify new version"
                },
                {
                    "key": "system.updateChannel",
                    "type": "selector",
                    "label": "prefs.updates.channel",
                    "description": "prefs.updates.channel.desc",
                    "keywords": "update channel stable beta git main pre-release prerelease nightly branch",
                    "options": [
                        {
                            "value": "stable",
                            "label": "prefs.updates.channel_stable"
                        },
                        {
                            "value": "beta",
                            "label": "prefs.updates.channel_beta"
                        },
                        {
                            "value": "git",
                            "label": "prefs.updates.channel_git"
                        }
                    ]
                }
            ]
        },
        {
            "id": "ocr",
            "title": "prefs.updates.section.ocr",
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
