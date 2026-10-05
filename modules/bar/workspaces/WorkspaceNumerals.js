.pragma library

// Numeral systems for the bar's workspace labels (workspaces.numeralStyle).
//
// Entry fields:
//   id        config value
//   label     human readable name
//   format(n) label for workspace n, or null when n is out of the system's
//             range (callers then fall back to arabic digits)
//   font      null: theme font. Otherwise the auto font (numeralFont = ""):
//             bundled  font files under the shell dir, first existing wins;
//                      `coverage` lists the glyphs the (subset) file has, any
//                      other label falls back to the system font; optional
//                      `weight` replaces the system font weight for it
//             lang     fontconfig language queried for a system font
//             prefer   family name fragments, best first; a family matching
//                      none of them is never picked (theme font instead)
//             avoid    family name fragments that are never picked
//             weight   CSS-like font weight (Font.* values), null = default
//   fit       null: digits keep the legacy text metrics. Otherwise labels are
//             fitted optically into the slot by their ink box:
//             em       glyph size relative to Config.theme.fontSize
//             width    max ink width relative to the slot
//             height   max ink height relative to the slot
//             condense narrowest horizontal compression of long labels before
//                      the whole label is scaled down
//
// To add a system, append an entry; validation and settings pick it up.

var DEFAULT_ID = "arabic";

function formatArabic(n) {
    return String(n);
}

var KANJI_DIGITS = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"];
var KANJI_UNITS = [[1000, "千"], [100, "百"], [10, "十"]];

// 1..9999 without the leading 一 on 十/百/千 (十一, 百一, 千).
function kanjiBelowMan(n) {
    var out = "";
    for (var i = 0; i < KANJI_UNITS.length; i++) {
        var unit = KANJI_UNITS[i][0];
        var count = Math.floor(n / unit);
        if (count > 0)
            out += (count > 1 ? KANJI_DIGITS[count] : "") + KANJI_UNITS[i][1];
        n %= unit;
    }
    return out + KANJI_DIGITS[n];
}

// Japanese positional numerals up to 9999 9999 (一万 = 10000).
function formatKanji(n) {
    if (!isInteger(n) || n < 1 || n > 99999999)
        return null;
    var man = Math.floor(n / 10000);
    var rest = n % 10000;
    return (man > 0 ? (man === 1 ? "一" : kanjiBelowMan(man)) + "万" : "") + (rest > 0 ? kanjiBelowMan(rest) : "");
}

var ROMAN = [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];

function formatRoman(n) {
    if (!isInteger(n) || n < 1 || n > 3999)
        return null;
    var out = "";
    for (var i = 0; i < ROMAN.length; i++) {
        while (n >= ROMAN[i][0]) {
            out += ROMAN[i][1];
            n -= ROMAN[i][0];
        }
    }
    return out;
}

function isInteger(n) {
    return typeof n === "number" && isFinite(n) && Math.floor(n) === n;
}

var SYSTEMS = [
    {
        id: "arabic",
        label: "Arabic",
        format: formatArabic,
        font: null,
        fit: null
    },
    {
        id: "kanji",
        label: "Kanji",
        format: formatKanji,
        font: {
            // Modern heavy rounded gothic: bundled M PLUS Rounded 1c Black subset
            // (OFL, assets/fonts/workspaces). To swap it, replace that subset
            // (or point `file` elsewhere); labels it can't cover fall back to
            // the installed Noto Sans CJK JP.
            bundled: [
                {
                    file: "assets/fonts/workspaces/kanji.subset.ttf",
                    coverage: "一二三四五六七八九十百千万"
                }
            ],
            lang: "ja",
            prefer: ["Noto Sans CJK JP", "Source Han Sans JP", "Sans CJK JP", "Sans JP", "Gothic"],
            avoid: ["Serif", "Mincho", "明朝"],
            weight: 900
        },
        fit: {
            em: 0.95,
            width: 0.56,
            height: 0.46,
            condense: 0.7
        }
    },
    {
        id: "roman",
        label: "Roman",
        format: formatRoman,
        font: null,
        fit: {
            em: 0.9,
            width: 0.56,
            height: 0.46,
            condense: 0.62
        }
    }
];

function ids() {
    return SYSTEMS.map(function (s) {
        return s.id;
    });
}

function isValid(id) {
    return ids().indexOf(id) !== -1;
}

function get(id) {
    for (var i = 0; i < SYSTEMS.length; i++) {
        if (SYSTEMS[i].id === id)
            return SYSTEMS[i];
    }
    return SYSTEMS[0];
}

function format(id, n) {
    var text = get(id).format(n);
    return text === null || text === undefined ? formatArabic(n) : text;
}

// Whether every character of `text` is in `coverage`.
function covers(coverage, text) {
    if (!coverage)
        return false;
    for (var i = 0; i < text.length; i++) {
        if (coverage.indexOf(text.charAt(i)) === -1)
            return false;
    }
    return text.length > 0;
}

// Output of the font probe: "file:<path>" lines for bundled files that
// exist, then `fc-list :lang=<lang> family` lines ("Fam,Fam Style").
// Returns { bundledFile, systemFamily } ("" when absent).
function parseFontProbe(output, prefer, avoid) {
    var bundledFile = "";
    var families = [];
    var lines = String(output || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (!line)
            continue;
        if (line.indexOf("file:") === 0) {
            if (!bundledFile)
                bundledFile = line.slice(5);
            continue;
        }
        var family = line.split(",")[0].trim();
        if (family && families.indexOf(family) === -1)
            families.push(family);
    }
    return {
        bundledFile: bundledFile,
        systemFamily: pickFamily(families, prefer || [], avoid || [])
    };
}

function matchesAny(name, fragments) {
    for (var i = 0; i < fragments.length; i++) {
        if (name.indexOf(fragments[i].toLowerCase()) !== -1)
            return true;
    }
    return false;
}

// Best family by `prefer` order; families matching `avoid` or none of
// `prefer` are skipped ("" when nothing qualifies).
function pickFamily(families, prefer, avoid) {
    var best = "";
    var bestRank = prefer.length;
    var sorted = families.slice().sort();
    for (var i = 0; i < sorted.length; i++) {
        var name = sorted[i].toLowerCase();
        if (matchesAny(name, avoid || []))
            continue;
        var rank = prefer.length;
        for (var j = 0; j < prefer.length; j++) {
            if (name.indexOf(prefer[j].toLowerCase()) !== -1) {
                rank = j;
                break;
            }
        }
        if (rank < bestRank) {
            best = sorted[i];
            bestRank = rank;
        }
    }
    return best;
}

// Optical fit of a label whose ink box measures inkWidth x inkHeight at the
// base pixel size. Returns { scale, condense }: the pixel size factor and
// the extra horizontal compression.
function fitLabel(fit, inkWidth, inkHeight, slotSize) {
    var maxWidth = slotSize * fit.width;
    var maxHeight = slotSize * fit.height;
    var scale = inkHeight > maxHeight && inkHeight > 0 ? maxHeight / inkHeight : 1;
    var width = inkWidth * scale;
    var condense = 1;
    if (width > maxWidth && width > 0) {
        condense = Math.max(fit.condense, maxWidth / width);
        if (width * condense > maxWidth)
            scale = maxWidth / (inkWidth * condense);
    }
    return {
        scale: scale,
        condense: condense
    };
}
