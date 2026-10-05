// Load a QML JavaScript library in node: strips `.pragma library` and
// resolves `.import "X.js" as Name` (relative to the file) recursively.
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

function loadLibrary(file, cache = new Map()) {
    const abs = path.resolve(file);
    if (cache.has(abs)) return cache.get(abs);
    const ctx = {};
    cache.set(abs, ctx);
    const src = fs.readFileSync(abs, 'utf8')
        .replace(/^\s*\.pragma library\s*$/m, '')
        .replace(/^\s*\.import\s+"([^"]+)"\s+as\s+(\w+)\s*;?\s*$/gm, (_, rel, name) => {
            ctx[name] = loadLibrary(path.join(path.dirname(abs), rel), cache);
            return '';
        });
    vm.runInNewContext(src, ctx);
    return ctx;
}

module.exports = { loadLibrary };
