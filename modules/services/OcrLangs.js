.pragma library

// Tesseract languages of the OCR tool: system.ocr.<code> booleans in the
// order of the settings chips (modules/settings/schema/updates.js OCR_KEYS,
// kept equal by tests/ocr-langs.test.cjs). eng and spa are on unless
// switched off, the others only when switched on.
var CODES = ["eng", "spa", "lat", "jpn", "chi_sim", "chi_tra", "kor", "rus"];
var DEFAULT_ON = { "eng": true, "spa": true };

// "eng+spa" for tesseract's -l; "eng" when nothing is selected.
function langs(cfg) {
    var out = [];
    CODES.forEach(function (c) {
        var v = cfg ? cfg[c] : undefined;
        if (v === undefined || v === null)
            v = !!DEFAULT_ON[c];
        if (v === true)
            out.push(c);
    });
    return (out.length > 0 ? out : ["eng"]).join("+");
}
