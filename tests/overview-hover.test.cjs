// Guard: hovering a window in the overview only highlights it; focus is a click.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('overview windows do not dispatch focus from hover handlers', () => {
    const dir = path.join(__dirname, '../modules/widgets/overview');
    for (const f of fs.readdirSync(dir).filter(n => n.endsWith('.qml'))) {
        const src = fs.readFileSync(path.join(dir, f), 'utf8');
        const handlers = src.match(/on(Entered|Exited|ContainsMouseChanged|HoveredChanged)\s*:\s*(\{[\s\S]*?\n\s{8}\}|[^\n]*)/g) || [];
        for (const h of handlers) assert.ok(!h.includes('focuswindow'), `${f}: ${h}`);
    }
});
