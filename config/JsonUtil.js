.pragma library

// Shared JSON helpers. Pure, no QML types (tests/json-util.test.cjs).

// Deep copy of plain JSON data. undefined and null pass through; values that
// cannot be serialised (cycles) are returned as they are.
function clone(v) {
    if (v === undefined || v === null)
        return v;
    if (typeof v !== "object")
        return v;
    try {
        return JSON.parse(JSON.stringify(v));
    } catch (e) {
        return v;
    }
}

function definedKeys(o) {
    return Object.keys(o).filter(function (k) {
        return o[k] !== undefined;
    });
}

// Deep, key-order independent comparison. Numbers compare with a small
// tolerance (and NaN equals NaN), and object keys whose value is undefined
// are ignored.
function deepEqual(a, b) {
    if (a === b)
        return true;
    if (typeof a === "number" && typeof b === "number")
        return (isNaN(a) && isNaN(b)) || Math.abs(a - b) < 1e-9;
    if (a === null || b === null || typeof a !== "object" || typeof b !== "object")
        return false;
    var la = Array.isArray(a), lb = Array.isArray(b);
    if (la !== lb)
        return false;
    if (la) {
        if (a.length !== b.length)
            return false;
        for (var i = 0; i < a.length; i++) {
            if (!deepEqual(a[i], b[i]))
                return false;
        }
        return true;
    }
    var ka = definedKeys(a), kb = definedKeys(b);
    if (ka.length !== kb.length)
        return false;
    for (var j = 0; j < ka.length; j++) {
        if (!Object.prototype.hasOwnProperty.call(b, ka[j]) || !deepEqual(a[ka[j]], b[ka[j]]))
            return false;
    }
    return true;
}
