.pragma library

// Search synonyms of the settings sidebar (SchemaUtil.search): the words
// people type for a setting that the schema names differently. A query word
// that starts with one of `words` (or a query holding one of the phrases)
// is also searched as each of `means`, which are words of the schema's
// English keywords / keys, so they find a row whatever the UI language.
// Russian and Spanish stems are listed since the UI is translated.
// Pure, node-tested: tests/settings-synonyms.test.cjs.

var SYNONYMS = [
    { "words": ["transparen", "see-through", "translucen", "прозрачн", "полупрозрачн", "непрозрачн", "opacidad", "translúcid"], "means": ["opacity", "glass"] },
    { "words": ["glass", "стекл", "cristal", "vidrio", "acrylic", "mica"], "means": ["glass"] },
    { "words": ["rounded corners", "round corners", "corner radius", "скругл", "закругл", "radius", "радиус", "esquinas redondeadas", "redonde"], "means": ["roundness", "rounding"] },
    { "words": ["corner", "углы", "угол", "esquina"], "means": ["corners", "roundness"] },
    { "words": ["island", "dynamic island", "остров", "вырез", "чёлк", "челк", "isla"], "means": ["notch"] },
    { "words": ["notch", "нотч"], "means": ["notch", "island"] },
    { "words": ["taskbar", "panel", "панел", "барра", "barra", "statusbar", "status bar", "waybar"], "means": ["bar"] },
    { "words": ["dock", "док", "app bar"], "means": ["dock"] },
    { "words": ["wallpaper", "background", "backdrop", "обои", "фон", "fondo"], "means": ["wallpaper"] },
    { "words": ["animation", "anim", "анимац", "движен", "animaci", "transition", "переход"], "means": ["motion", "animation"] },
    { "words": ["speed", "скорост", "velocidad", "fast", "slow", "быстр", "медлен"], "means": ["speed", "motion"] },
    { "words": ["shadow", "тень", "тени", "теней", "sombra", "depth", "глубин", "profundidad"], "means": ["shadow", "depth"] },
    { "words": ["blur", "размыт", "desenfoque", "frosted", "матов"], "means": ["blur", "glass"] },
    { "words": ["font", "typeface", "шрифт", "fuente", "tipograf"], "means": ["font"] },
    { "words": ["dark mode", "night", "тёмн", "темн", "ночн", "oscuro", "noche"], "means": ["dark"] },
    { "words": ["light mode", "светл", "claro"], "means": ["light"] },
    { "words": ["colour", "color", "цвет", "палитр", "colores"], "means": ["color", "palette", "scheme"] },
    { "words": ["notification", "toast", "popup", "уведомл", "оповещ", "notificaci"], "means": ["notifications"] },
    { "words": ["lock", "блокир", "экран блок", "bloqueo"], "means": ["lockscreen", "lock"] },
    { "words": ["gap", "spacing", "padding", "отступ", "зазор", "промежут", "hueco", "espaciado"], "means": ["gaps", "spacing", "density"] },
    { "words": ["density", "плотност", "компакт", "densidad", "compact"], "means": ["density", "compact"] },
    { "words": ["size", "scale", "zoom", "размер", "масштаб", "tamaño", "escala"], "means": ["size", "scale"] },
    { "words": ["icon", "значк", "иконк", "icono"], "means": ["icons"] },
    { "words": ["keyboard", "клавиатур", "раскладк", "teclado", "layout switch"], "means": ["keyboard"] },
    { "words": ["shortcut", "hotkey", "keybind", "горяч", "сочетан", "клавиш", "atajo"], "means": ["keybinds", "shortcuts"] },
    { "words": ["clock", "часы", "время", "reloj", "hora"], "means": ["clock", "time"] },
    { "words": ["volume", "громкост", "звук", "volumen", "sonido", "audio"], "means": ["volume", "sound"] },
    { "words": ["brightness", "яркост", "brillo"], "means": ["brightness"] },
    { "words": ["launcher", "app menu", "start menu", "лаунчер", "запуск", "lanzador"], "means": ["launcher"] },
    { "words": ["workspace", "рабоч", "virtual desktop", "escritorio"], "means": ["workspaces"] },
    { "words": ["monitor", "display", "screen", "монитор", "экран", "дисплей", "pantalla"], "means": ["displays", "screen"] },
    { "words": ["ai", "assistant", "chatbot", "llm", "ассистент", "нейросет", "asistente"], "means": ["ai", "assistant"] },
    { "words": ["theme", "look", "тема", "внешн", "tema", "apariencia"], "means": ["theme", "appearance"] },
    { "words": ["preset", "пресет", "шаблон", "preajuste"], "means": ["preset"] },
    { "words": ["sleep", "idle", "suspend", "сон", "простой", "ожидан", "suspender", "inactividad"], "means": ["idle"] },
    { "words": ["power", "shutdown", "питани", "выключ", "energía", "apagar"], "means": ["power"] },
    { "words": ["weather", "погод", "clima", "tiempo"], "means": ["weather"] },
    { "words": ["border", "outline", "рамк", "границ", "обводк", "borde"], "means": ["border", "frame"] },
    { "words": ["wifi", "wi-fi", "internet", "сеть", "интернет"], "means": ["network", "wifi"] },
    { "words": ["bluetooth", "блютуз", "блютус"], "means": ["bluetooth"] },
    { "words": ["clipboard", "буфер", "portapapeles"], "means": ["clipboard"] },
    { "words": ["screenshot", "скриншот", "снимок", "captura"], "means": ["screenshot"] },
    { "words": ["terminal", "терминал", "консол", "kitty"], "means": ["terminal"] }
];

// Is `term` in the query: a phrase anywhere, one word at a query word start
// (a short one, e.g. "ai", only as a whole word).
function hit(q, words, term) {
    if (term.indexOf(" ") !== -1)
        return q.indexOf(term) !== -1;
    for (var i = 0; i < words.length; i++) {
        if (term.length <= 3 ? words[i] === term : words[i].indexOf(term) === 0)
            return true;
    }
    return false;
}

// Replace the matched phrase / word of `q` by `meaning`.
function substitute(q, words, term, meaning) {
    if (term.indexOf(" ") !== -1)
        return q.split(term).join(meaning).replace(/\s+/g, " ").trim();
    return words.map(function (w) {
        return (term.length <= 3 ? w === term : w.indexOf(term) === 0) ? meaning : w;
    }).join(" ");
}

// Other queries meaning the same as `query`: [string], without the query
// itself and without duplicates.
function alternatives(query) {
    var q = String(query || "").trim().toLowerCase();
    if (!q)
        return [];
    var words = q.split(/\s+/);
    var out = [];
    SYNONYMS.forEach(function (s) {
        for (var i = 0; i < s.words.length; i++) {
            var term = s.words[i].trim();
            if (!hit(q, words, term))
                continue;
            s.means.forEach(function (m) {
                var alt = substitute(q, words, term, m);
                if (alt !== q && out.indexOf(alt) === -1)
                    out.push(alt);
            });
            return;
        }
    });
    return out;
}
