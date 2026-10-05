.pragma library
.import "Calc.js" as Calc

// Offline unit and currency conversion for the launcher calculator:
//   "5 kg in lb", "100 usd to rub", "72f in c", "3.5 gib as mb", "10 km/h to mph"
// Units are factors to the base unit of their dimension; temperature has
// offset functions. Currency rates are passed in (base USD), see
// CurrencyRates.qml.

var UNITS = {
    "length": {
        "base": "m",
        "units": {
            "mm": [0.001, ["millimeter", "millimeters", "millimetre", "millimetres"]],
            "cm": [0.01, ["centimeter", "centimeters", "centimetre", "centimetres"]],
            "m": [1, ["meter", "meters", "metre", "metres"]],
            "km": [1000, ["kilometer", "kilometers", "kilometre", "kilometres"]],
            "in": [0.0254, ["inch", "inches", "\""]],
            "ft": [0.3048, ["foot", "feet", "'"]],
            "yd": [0.9144, ["yard", "yards"]],
            "mi": [1609.344, ["mile", "miles"]],
            "nmi": [1852, ["nautical mile", "nautical miles"]]
        }
    },
    "mass": {
        "base": "kg",
        "units": {
            "mg": [1e-6, ["milligram", "milligrams"]],
            "g": [0.001, ["gram", "grams"]],
            "kg": [1, ["kilogram", "kilograms", "kilo", "kilos"]],
            "t": [1000, ["tonne", "tonnes", "ton", "tons"]],
            "oz": [0.028349523125, ["ounce", "ounces"]],
            "lb": [0.45359237, ["lbs", "pound", "pounds"]],
            "st": [6.35029318, ["stone", "stones"]]
        }
    },
    "volume": {
        "base": "l",
        "units": {
            "ml": [0.001, ["milliliter", "milliliters", "millilitre", "millilitres"]],
            "l": [1, ["liter", "liters", "litre", "litres"]],
            "tsp": [0.00492892159375, ["teaspoon", "teaspoons"]],
            "tbsp": [0.01478676478125, ["tablespoon", "tablespoons"]],
            "floz": [0.0295735295625, ["fl oz", "fluid ounce", "fluid ounces"]],
            "cup": [0.2365882365, ["cups"]],
            "pt": [0.473176473, ["pint", "pints"]],
            "qt": [0.946352946, ["quart", "quarts"]],
            "gal": [3.785411784, ["gallon", "gallons"]]
        }
    },
    "area": {
        "base": "m2",
        "units": {
            "cm2": [1e-4, ["cm²", "square centimeter", "square centimeters"]],
            "m2": [1, ["m²", "sqm", "square meter", "square meters"]],
            "km2": [1e6, ["km²", "square kilometer", "square kilometers"]],
            "ft2": [0.09290304, ["ft²", "sqft", "square foot", "square feet"]],
            "ac": [4046.8564224, ["acre", "acres"]],
            "ha": [10000, ["hectare", "hectares"]]
        }
    },
    "speed": {
        "base": "m/s",
        "units": {
            "m/s": [1, ["mps", "meters per second"]],
            "km/h": [1 / 3.6, ["kmh", "kph", "kilometers per hour"]],
            "mph": [0.44704, ["miles per hour"]],
            "kn": [0.514444444, ["knot", "knots", "kt"]]
        }
    },
    "data": {
        "base": "b",
        "units": {
            "bit": [0.125, ["bits"]],
            "b": [1, ["byte", "bytes"]],
            "kb": [1e3, ["kilobyte", "kilobytes"]],
            "mb": [1e6, ["megabyte", "megabytes"]],
            "gb": [1e9, ["gigabyte", "gigabytes"]],
            "tb": [1e12, ["terabyte", "terabytes"]],
            "kib": [1024, ["kibibyte", "kibibytes"]],
            "mib": [1048576, ["mebibyte", "mebibytes"]],
            "gib": [1073741824, ["gibibyte", "gibibytes"]],
            "tib": [1099511627776, ["tebibyte", "tebibytes"]]
        }
    },
    "time": {
        "base": "s",
        "units": {
            "ms": [0.001, ["millisecond", "milliseconds"]],
            "s": [1, ["sec", "secs", "second", "seconds"]],
            "min": [60, ["mins", "minute", "minutes"]],
            "h": [3600, ["hr", "hrs", "hour", "hours"]],
            "d": [86400, ["day", "days"]],
            "wk": [604800, ["week", "weeks"]],
            "yr": [31557600, ["year", "years"]]
        }
    },
    "temperature": {
        "base": "c",
        "units": {
            "c": [null, ["°c", "celsius", "degc"]],
            "f": [null, ["°f", "fahrenheit", "degf"]],
            "k": [null, ["kelvin"]]
        }
    }
};

var TEMP = {
    "c": {
        "to": v => v,
        "from": v => v
    },
    "f": {
        "to": v => (v - 32) * 5 / 9,
        "from": v => v * 9 / 5 + 32
    },
    "k": {
        "to": v => v - 273.15,
        "from": v => v + 273.15
    }
};

// Currency symbols and common names -> ISO code.
var CURRENCY_ALIASES = {
    "$": "USD",
    "us$": "USD",
    "dollar": "USD",
    "dollars": "USD",
    "€": "EUR",
    "euro": "EUR",
    "euros": "EUR",
    "£": "GBP",
    "pound sterling": "GBP",
    "¥": "JPY",
    "yen": "JPY",
    "₽": "RUB",
    "руб": "RUB",
    "rouble": "RUB",
    "roubles": "RUB",
    "ruble": "RUB",
    "rubles": "RUB",
    "₴": "UAH",
    "hryvnia": "UAH",
    "₹": "INR",
    "rupee": "INR",
    "rupees": "INR",
    "₩": "KRW",
    "won": "KRW",
    "₺": "TRY",
    "lira": "TRY",
    "zł": "PLN",
    "zloty": "PLN",
    "yuan": "CNY",
    "rmb": "CNY",
    "franc": "CHF",
    "francs": "CHF",
    "real": "BRL",
    "reais": "BRL",
    "₿": "BTC"
};

var _index = null;

function index() {
    if (_index)
        return _index;
    _index = {};
    Object.keys(UNITS).forEach(dim => {
        const units = UNITS[dim].units;
        Object.keys(units).forEach(sym => {
            _index[sym] = {
                "dim": dim,
                "sym": sym
            };
            units[sym][1].forEach(alias => {
                _index[alias] = {
                    "dim": dim,
                    "sym": sym
                };
            });
        });
    });
    return _index;
}

function unit(name) {
    const k = String(name || "").trim().toLowerCase().replace(/\s+/g, " ");
    return index()[k] || index()[k.replace(/\.$/, "")] || null;
}

function currency(name, rates) {
    const raw = String(name || "").trim();
    const k = raw.toLowerCase();
    const code = CURRENCY_ALIASES[k] || (/^[a-z]{3}$/i.test(raw) ? raw.toUpperCase() : null);
    if (!code || !rates || rates[code] === undefined)
        return null;
    return code;
}

// "<amount> <from> (in|to|as|->|=>) <to>" -> [{amount, from, to}...], one
// candidate per separator position ("5 in in cm" has two). The amount may
// be an expression ("2*3 kg in lb") or a glued symbol ("$100 in eur",
// "100€ to usd").
function split(query) {
    const s = String(query || "").trim();
    const out = [];
    const sep = /\s+(?:in|to|as|into|->|=>|в)(?=\s+\S)/gi;
    let m;
    while ((m = sep.exec(s)) !== null) {
        const left = s.substring(0, m.index).trim();
        const to = s.substring(m.index + m[0].length).trim();
        const q = _amount(left);
        if (q && to !== "")
            out.push({
                "amount": q.amount,
                "from": q.from,
                "to": to
            });
    }
    return out;
}

function _amount(left) {
    // amount then unit ("5 kg", "5kg", "100€", "2*3 lb")
    let a = /^([-+]?[\d.\s*\/+()^×-]*\d[\d.)]*%?)\s*(\D.*)$/.exec(left);
    if (a) {
        const amount = Calc.evaluate(a[1]);
        if (amount !== null)
            return {
                "amount": amount,
                "from": a[2].trim()
            };
    }
    // symbol then amount ("$100")
    a = /^([^\d\s.+-]{1,3})\s*([\d.]+)$/.exec(left);
    if (a) {
        const amount = Calc.evaluate(a[2]);
        if (amount !== null)
            return {
                "amount": amount,
                "from": a[1]
            };
    }
    return null;
}

// Converts a query. `rates` maps ISO codes to units per 1 USD.
// Returns {value, amount, from, to, kind: "unit"|"currency", dim} or null.
function convert(query, rates) {
    const cands = split(query);
    for (let i = 0; i < cands.length; i++) {
        const r = _convert(cands[i], rates);
        if (r)
            return r;
    }
    return null;
}

function _convert(q, rates) {
    const fu = unit(q.from);
    const tu = unit(q.to);
    if (fu && tu && fu.dim === tu.dim) {
        let value;
        if (fu.dim === "temperature")
            value = TEMP[tu.sym].from(TEMP[fu.sym].to(q.amount));
        else
            value = q.amount * UNITS[fu.dim].units[fu.sym][0] / UNITS[tu.dim].units[tu.sym][0];
        return {
            "value": value,
            "amount": q.amount,
            "from": fu.sym,
            "to": tu.sym,
            "kind": "unit",
            "dim": fu.dim
        };
    }
    const fc = currency(q.from, rates);
    const tc = currency(q.to, rates);
    if (fc && tc) {
        return {
            "value": q.amount / rates[fc] * rates[tc],
            "amount": q.amount,
            "from": fc,
            "to": tc,
            "kind": "currency",
            "dim": "currency"
        };
    }
    return null;
}

// Display symbol of a unit ("m2" -> "m²").
function label(sym) {
    return String(sym).replace("2", "²");
}
