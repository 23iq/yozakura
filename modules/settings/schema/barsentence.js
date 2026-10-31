.pragma library
.import "../../bar/sentence/Sentence.js" as Sentence

// The sentence bar module (modules/bar/modules/Sentence.qml), spliced into
// bar.js after the media section. Entry format: see modules/settings/AGENTS.md.

var CHOICES = Sentence.FRAGMENTS.map(function (id) {
    return {
        "value": id,
        "label": "prefs.bar.sentence.fragment." + id
    };
});

function _options(key, values) {
    return values.map(function (v) {
        return {
            "value": v,
            "label": key + "." + v
        };
    });
}

var sections = [
    {
        "id": "sentence",
        "title": "prefs.bar.section.sentence",
        "entries": [
            {
                "key": "bar.moduleOptions.sentence.separator",
                "type": "selector",
                "preview": "SentencePreview",
                "label": "prefs.bar.sentence_separator",
                "description": "prefs.bar.sentence_separator.desc",
                "keywords": "sentence line separator dash dot comma kotoba words",
                "options": _options("prefs.bar.sentence_separator", Sentence.SEPARATORS)
            },
            {
                "key": "bar.moduleOptions.sentence.verbosity",
                "type": "selector",
                "label": "prefs.bar.sentence_verbosity",
                "description": "prefs.bar.sentence_verbosity.desc",
                "keywords": "sentence wording short full phrases words",
                "options": _options("prefs.bar.sentence_verbosity", Sentence.VERBOSITIES)
            },
            {
                "key": "bar.moduleOptions.sentence.typeface",
                "type": "selector",
                "label": "prefs.bar.sentence_typeface",
                "description": "prefs.bar.sentence_typeface.desc",
                "keywords": "sentence font typeface serif editorial",
                "options": _options("prefs.bar.sentence_typeface", ["body", "editorial"])
            },
            {
                "key": "bar.moduleOptions.sentence.fragments",
                "type": "custom",
                "component": "OrderedListEditor",
                "subset": true,
                "choices": CHOICES,
                "label": "prefs.bar.sentence_fragments",
                "description": "prefs.bar.sentence_fragments.desc",
                "keywords": "sentence fragments order clock window workspace battery network volume media notifications weather"
            },
            {
                "key": "bar.moduleOptions.sentence.priority",
                "type": "custom",
                "component": "OrderedListEditor",
                "choices": CHOICES,
                "label": "prefs.bar.sentence_priority",
                "description": "prefs.bar.sentence_priority.desc",
                "keywords": "sentence priority narrow overflow drop keep"
            },
            {
                "key": "bar.moduleOptions.sentence.maxWidth",
                "type": "slider",
                "min": 0,
                "max": 2000,
                "step": 20,
                "unit": "px",
                "specialValues": [
                    {
                        "value": 0,
                        "label": "prefs.bar.sentence_max_width.auto"
                    }
                ],
                "label": "prefs.bar.sentence_max_width",
                "description": "prefs.bar.sentence_max_width.desc",
                "keywords": "sentence width length longest line"
            }
        ]
    }
];
