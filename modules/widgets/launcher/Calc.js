.pragma library

// Safe arithmetic for the launcher calculator: a small recursive-descent
// parser (no eval). Grammar:
//   expr   := term (("+" | "-") term)*
//   term   := factor (("*" | "/" | "mod" | implicit) factor)*
//   factor := unary
//   unary  := ("-" | "+") unary | power
//   power  := postfix ("^" unary)?            (right associative)
//   postfix:= primary ("%" | "!")*
//   primary:= number | const | func "(" expr ("," expr)* ")" | "(" expr ")"
// "x", "×", "·" multiply, "÷" divides, "**" is "^", "," inside numbers is
// not supported (it separates function arguments).

var FUNCS = {
    "sqrt": Math.sqrt,
    "cbrt": Math.cbrt,
    "abs": Math.abs,
    "round": Math.round,
    "floor": Math.floor,
    "ceil": Math.ceil,
    "exp": Math.exp,
    "ln": Math.log,
    "log": function (x, b) {
        return b === undefined ? Math.log10(x) : Math.log(x) / Math.log(b);
    },
    "log2": Math.log2,
    "sin": Math.sin,
    "cos": Math.cos,
    "tan": Math.tan,
    "asin": Math.asin,
    "acos": Math.acos,
    "atan": Math.atan,
    "min": Math.min,
    "max": Math.max,
    "pow": Math.pow
};

var CONSTS = {
    "pi": Math.PI,
    "π": Math.PI,
    "e": Math.E,
    "tau": 2 * Math.PI
};

function tokenize(src) {
    const out = [];
    let i = 0;
    const s = String(src).replace(/\*\*/g, "^").replace(/[×·]/g, "*").replace(/÷/g, "/").replace(/−/g, "-");
    while (i < s.length) {
        const c = s[i];
        if (/\s/.test(c)) {
            i++;
            continue;
        }
        const num = /^(\d+\.?\d*|\.\d+)(e[+-]?\d+)?/i.exec(s.substring(i));
        if (num) {
            out.push({
                "t": "num",
                "v": parseFloat(num[0])
            });
            i += num[0].length;
            continue;
        }
        const word = /^[a-zπ]+/i.exec(s.substring(i));
        if (word) {
            let w = word[0].toLowerCase();
            // log2( is the only name with a digit; "12x7" must stay 12 x 7.
            if (w === "log" && /^2\s*\(/.test(s.substring(i + 3)))
                w = "log2";
            out.push({
                "t": "word",
                "v": w
            });
            i += w.length;
            continue;
        }
        if ("+-*/^%!(),".indexOf(c) !== -1) {
            out.push({
                "t": "op",
                "v": c
            });
            i++;
            continue;
        }
        throw new Error("unexpected " + c);
    }
    return out;
}

function factorial(n) {
    if (n < 0 || Math.floor(n) !== n || n > 170)
        throw new Error("bad factorial");
    let r = 1;
    for (let i = 2; i <= n; i++)
        r *= i;
    return r;
}

function parse(tokens) {
    let pos = 0;
    const peek = () => tokens[pos];
    const isOp = (v) => peek() && peek().t === "op" && peek().v === v;
    const eat = (v) => {
        if (!isOp(v))
            throw new Error("expected " + v);
        pos++;
    };

    function primary() {
        const tk = peek();
        if (!tk)
            throw new Error("unexpected end");
        if (tk.t === "num") {
            pos++;
            return tk.v;
        }
        if (tk.t === "op" && tk.v === "(") {
            pos++;
            const v = expr();
            eat(")");
            return v;
        }
        if (tk.t === "word") {
            pos++;
            if (FUNCS.hasOwnProperty(tk.v) && isOp("(")) {
                pos++;
                const args = [expr()];
                while (isOp(",")) {
                    pos++;
                    args.push(expr());
                }
                eat(")");
                return FUNCS[tk.v].apply(null, args);
            }
            if (CONSTS.hasOwnProperty(tk.v))
                return CONSTS[tk.v];
            throw new Error("unknown " + tk.v);
        }
        throw new Error("unexpected " + tk.v);
    }

    function postfix() {
        let v = primary();
        while (isOp("%") || isOp("!")) {
            if (peek().v === "%")
                v = v / 100;
            else
                v = factorial(v);
            pos++;
        }
        return v;
    }

    function unary() {
        if (isOp("-")) {
            pos++;
            return -unary();
        }
        if (isOp("+")) {
            pos++;
            return unary();
        }
        return power();
    }

    // -3^2 = -(3^2); 2^-1 works because the exponent is a unary.
    function power() {
        const base = postfix();
        if (isOp("^")) {
            pos++;
            return Math.pow(base, unary());
        }
        return base;
    }

    function factor() {
        return unary();
    }

    function startsFactor() {
        const tk = peek();
        if (!tk)
            return false;
        return tk.t === "num" || (tk.t === "word" && tk.v !== "x" && tk.v !== "mod") || (tk.t === "op" && tk.v === "(");
    }

    function term() {
        let v = factor();
        for (;;) {
            const tk = peek();
            if (tk && tk.t === "op" && (tk.v === "*" || tk.v === "/")) {
                pos++;
                const r = factor();
                v = tk.v === "*" ? v * r : v / r;
            } else if (tk && tk.t === "word" && tk.v === "x") {
                pos++;
                v = v * factor();
            } else if (tk && tk.t === "word" && tk.v === "mod") {
                pos++;
                const r = factor();
                v = ((v % r) + r) % r;
            } else if (startsFactor()) {
                // implicit multiplication: 2pi, 3(4+1)
                v = v * factor();
            } else {
                return v;
            }
        }
    }

    function expr() {
        let v = term();
        while (isOp("+") || isOp("-")) {
            const op = peek().v;
            pos++;
            const r = term();
            v = op === "+" ? v + r : v - r;
        }
        return v;
    }

    const v = expr();
    if (pos !== tokens.length)
        throw new Error("trailing input");
    return v;
}

// Value of `src`, or null when it is not an expression.
function evaluate(src) {
    try {
        const tokens = tokenize(src);
        if (tokens.length === 0)
            return null;
        const v = parse(tokens);
        return (typeof v === "number" && isFinite(v)) ? v : null;
    } catch (e) {
        return null;
    }
}

// True when `src` looks like a calculation rather than a word or a lone
// number (mixed search should not show "= 42" for "42" or "e").
function looksLikeMath(src) {
    const s = String(src || "").trim();
    if (s === "")
        return false;
    const tokens = (() => {
            try {
                return tokenize(s);
            } catch (e) {
                return null;
            }
        })();
    if (!tokens || tokens.length < 2)
        return false;
    const hasNumber = tokens.some(t => t.t === "num");
    const hasOperator = tokens.some(t => t.t === "op" && t.v !== "(" && t.v !== ")" && t.v !== ",") || tokens.some(t => t.t === "word" && (FUNCS.hasOwnProperty(t.v) || t.v === "x" || t.v === "mod"));
    return hasNumber && hasOperator;
}

// Human formatting: up to `digits` significant digits, no float noise,
// thin grouping of the integer part.
function format(v, digits) {
    if (v === null || v === undefined || !isFinite(v))
        return "";
    digits = digits || 12;
    if (v === 0)
        return "0";
    const abs = Math.abs(v);
    if (abs >= 1e15 || abs < 1e-9)
        return v.toExponential(6).replace(/\.?0+e/, "e");
    let s = Number(v.toPrecision(digits)).toString();
    if (s.indexOf("e") !== -1)
        return s;
    const neg = s[0] === "-";
    if (neg)
        s = s.substring(1);
    const parts = s.split(".");
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, "\u202f");
    return (neg ? "-" : "") + parts.join(".");
}

// Plain machine form (copied to the clipboard): no grouping.
function plain(v) {
    if (v === null || v === undefined || !isFinite(v))
        return "";
    return String(Number(v.toPrecision(12)));
}
