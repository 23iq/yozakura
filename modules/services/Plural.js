.pragma library

// CLDR plural category of an integer count: "one" | "few" | "many" | "other".
// en/es (and the default): one when n == 1. ru/uk/be: one/few/many by the
// last digits. Used by I18n.tn(); tests/plural.test.cjs.
function category(lang, n) {
    var i = Math.abs(Math.floor(Number(n) || 0));
    var base = String(lang || "").toLowerCase().split(/[-_]/)[0];
    if (base === "ru" || base === "uk" || base === "be") {
        var m10 = i % 10;
        var m100 = i % 100;
        if (m10 === 1 && m100 !== 11)
            return "one";
        if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14))
            return "few";
        return "many";
    }
    return i === 1 ? "one" : "other";
}
