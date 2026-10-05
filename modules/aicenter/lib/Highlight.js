.pragma library
.import "Markdown.js" as Markdown

// Small palette-driven syntax highlighter (no external themes, so every preset
// colors code with its own roles). tokenizeLine() is stateful across lines for
// block comments and multi-line strings; toHtml() renders spans with the colors
// supplied by the caller: {kw, str, com, num, fn, type, lit}.

var C_LIKE = { line: "//", block: ["/*", "*/"], strings: ["\"", "'", "`"] };
var HASH = { line: "#", block: null, strings: ["\"", "'"] };

var LANGS = {
    js: { syntax: C_LIKE, kw: "break case catch class const continue debugger default delete do else export extends finally for function if import in instanceof let new of return super switch this throw try typeof var void while with yield async await static get set readonly property signal required pragma interface type enum implements namespace declare as from" },
    go: { syntax: C_LIKE, kw: "break case chan const continue default defer else fallthrough for func go goto if import interface map package range return select struct switch type var any error string int int64 float64 bool byte rune uint" },
    rust: { syntax: C_LIKE, kw: "as async await break const continue crate dyn else enum extern fn for if impl in let loop match mod move mut pub ref return self Self static struct super trait type unsafe use where while" },
    c: { syntax: C_LIKE, kw: "auto break case char const continue default do double else enum extern float for goto if inline int long register return short signed sizeof static struct switch typedef union unsigned void volatile while class namespace template typename public private protected virtual override using new delete nullptr bool include define" },
    java: { syntax: C_LIKE, kw: "abstract boolean break byte case catch char class const continue default do double else enum extends final finally float for if implements import instanceof int interface long native new package private protected public return short static super switch synchronized this throw throws try void volatile while val var fun object when data sealed" },
    python: { syntax: { line: "#", block: null, strings: ["\"\"\"", "'''", "\"", "'"] }, kw: "and as assert async await break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield self match case" },
    sh: { syntax: HASH, kw: "if then else elif fi for while until do done case esac function in return local export readonly declare source exit set unset shift break continue echo printf cd" },
    lua: { syntax: { line: "--", block: ["--[[", "]]"], strings: ["\"", "'"] }, kw: "and break do else elseif end for function goto if in local not or repeat return then until while" },
    nix: { syntax: { line: "#", block: ["/*", "*/"], strings: ["\"", "''"] }, kw: "let in with rec inherit if then else assert import" },
    sql: { syntax: { line: "--", block: ["/*", "*/"], strings: ["'", "\""] }, kw: "select from where insert into values update set delete create table drop alter add index join left right inner outer on group by order having limit offset as and or not null primary key distinct union" },
    css: { syntax: { line: null, block: ["/*", "*/"], strings: ["\"", "'"] }, kw: "important media import from to" },
    json: { syntax: { line: null, block: null, strings: ["\""] }, kw: "" },
    yaml: { syntax: HASH, kw: "" },
    toml: { syntax: HASH, kw: "" },
    diff: { syntax: { line: null, block: null, strings: [] }, kw: "" },
    text: { syntax: { line: null, block: null, strings: [] }, kw: "" }
};

var ALIASES = {
    javascript: "js", jsx: "js", ts: "js", tsx: "js", typescript: "js", qml: "js", mjs: "js", cjs: "js",
    golang: "go", rs: "rust", h: "c", hpp: "c", cpp: "c", cc: "c", cxx: "c", "c++": "c", cs: "java", kotlin: "java", kt: "java", swift: "java", dart: "java",
    py: "python", bash: "sh", zsh: "sh", shell: "sh", fish: "sh", console: "sh", shellscript: "sh",
    jsonc: "json", json5: "json", yml: "yaml", scss: "css", less: "css", patch: "diff", txt: "text", plaintext: "text", "": "text"
};

var LITERALS = { "true": 1, "false": 1, "null": 1, "nil": 1, "None": 1, "True": 1, "False": 1, "undefined": 1, "NULL": 1 };

var _kwCache = {};

function language(name) {
    var n = String(name || "").toLowerCase();
    if (LANGS[n])
        return n;
    if (ALIASES[n] !== undefined)
        return ALIASES[n];
    return "text";
}

// Language from a file path ("src/a.go" -> "go").
function languageForPath(path) {
    var p = String(path || "");
    var base = p.split("/").pop();
    if (base === "Makefile" || base === "Dockerfile")
        return "sh";
    var dot = base.lastIndexOf(".");
    return dot < 0 ? "text" : language(base.substring(dot + 1));
}

function _keywords(lang) {
    if (!_kwCache[lang]) {
        var set = {};
        var words = (LANGS[lang] ? LANGS[lang].kw : "").split(" ");
        for (var i = 0; i < words.length; i++)
            if (words[i])
                set[words[i]] = 1;
        _kwCache[lang] = set;
    }
    return _kwCache[lang];
}

function newState() {
    return { block: false, string: "" };
}

function _startsWith(line, i, token) {
    return token && line.substr(i, token.length) === token;
}

// Returns [{t: text, k: kind}] where kind is "" (plain), kw, str, com, num, fn, type, lit.
function tokenizeLine(line, lang, state) {
    var l = language(lang);
    var def = LANGS[l];
    var syn = def.syntax;
    var kws = _keywords(l);
    var st = state || newState();
    var out = [];
    var i = 0;
    var n = line.length;

    function push(text, kind) {
        if (!text)
            return;
        var last = out.length > 0 ? out[out.length - 1] : null;
        if (last && last.k === kind)
            last.t += text;
        else
            out.push({ t: text, k: kind });
    }

    if (l === "text" || l === "diff") {
        push(line, "");
        return out;
    }

    while (i < n) {
        if (st.block) {
            var end = line.indexOf(syn.block[1], i);
            if (end < 0) {
                push(line.substring(i), "com");
                return out;
            }
            push(line.substring(i, end + syn.block[1].length), "com");
            i = end + syn.block[1].length;
            st.block = false;
            continue;
        }
        if (st.string) {
            var q = st.string;
            var j = i;
            while (j < n) {
                if (line.charAt(j) === "\\" && q !== "`" && q.length === 1) {
                    j += 2;
                    continue;
                }
                if (_startsWith(line, j, q))
                    break;
                j++;
            }
            if (j >= n) {
                push(line.substring(i), "str");
                if (q.length === 1 && q !== "`")
                    st.string = ""; // single-line strings do not continue
                return out;
            }
            push(line.substring(i, j + q.length), "str");
            i = j + q.length;
            st.string = "";
            continue;
        }
        if (syn.line && _startsWith(line, i, syn.line) && !(syn.block && _startsWith(line, i, syn.block[0]))) {
            push(line.substring(i), "com");
            return out;
        }
        if (syn.block && _startsWith(line, i, syn.block[0])) {
            st.block = true;
            push(syn.block[0], "com");
            i += syn.block[0].length;
            continue;
        }
        var opened = "";
        for (var s = 0; s < syn.strings.length; s++) {
            if (_startsWith(line, i, syn.strings[s])) {
                opened = syn.strings[s];
                break;
            }
        }
        if (opened) {
            push(opened, "str");
            i += opened.length;
            st.string = opened;
            continue;
        }
        var ch = line.charAt(i);
        if (/[0-9]/.test(ch) && (i === 0 || !/[\w.]/.test(line.charAt(i - 1)))) {
            var m = /^(0x[0-9a-fA-F_]+|[0-9][0-9_]*(\.[0-9_]+)?([eE][+-]?[0-9]+)?)/.exec(line.substring(i));
            push(m[0], "num");
            i += m[0].length;
            continue;
        }
        if (/[A-Za-z_$@]/.test(ch)) {
            var w = /^[A-Za-z_$@][\w$]*/.exec(line.substring(i))[0];
            var after = line.substring(i + w.length);
            var kind = "";
            if (kws[w])
                kind = "kw";
            else if (LITERALS[w])
                kind = "lit";
            else if (/^\s*\(/.test(after))
                kind = "fn";
            else if (/^[A-Z][a-z0-9]/.test(w))
                kind = "type";
            if ((l === "yaml" || l === "toml") && /^\s*[:=]/.test(after))
                kind = "kw";
            push(w, kind);
            i += w.length;
            continue;
        }
        if (l === "json" && ch === "\"") {
            push(ch, "str");
            i++;
            continue;
        }
        push(ch, "");
        i++;
    }
    return out;
}

function toHtml(tokens, colors) {
    var html = "";
    for (var i = 0; i < tokens.length; i++) {
        var tok = tokens[i];
        var text = Markdown.escapeHtml(tok.t).replace(/ /g, "&nbsp;").replace(/\t/g, "&nbsp;&nbsp;&nbsp;&nbsp;");
        var color = tok.k && colors ? colors[tok.k] : "";
        if (color) {
            var style = "color:" + color + (tok.k === "com" ? ";font-style:italic" : "");
            html += "<span style=\"" + style + "\">" + text + "</span>";
        } else {
            html += text;
        }
    }
    return html;
}

// Highlights a whole snippet; returns one HTML string per line.
function highlightLines(code, lang, colors) {
    var lines = String(code === undefined || code === null ? "" : code).split("\n");
    var state = newState();
    var out = [];
    for (var i = 0; i < lines.length; i++)
        out.push(toHtml(tokenizeLine(lines[i], lang, state), colors));
    return out;
}

// Whole snippet as one rich-text block (lines joined with <br>).
function highlight(code, lang, colors) {
    return highlightLines(code, lang, colors).join("<br>");
}

// Token colors from the shell palette (pass the Colors singleton).
function paletteFrom(c) {
    return {
        kw: String(c.primary), lit: String(c.primary), type: String(c.secondary), fn: String(c.secondary),
        str: String(c.tertiary), num: String(c.tertiary), com: String(c.outline)
    };
}
