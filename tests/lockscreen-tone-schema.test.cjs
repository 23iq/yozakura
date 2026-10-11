// The lock screen tone selector is hidden for styles that draw one tone only
// (their registry `tones` has a single entry): modules/settings/schema/lockscreen.js.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const SchemaUtil = loadLibrary(path.join(__dirname, '..', 'modules/settings/SchemaUtil.js'));
const Lock = loadLibrary(path.join(__dirname, '..', 'modules/settings/schema/lockscreen.js'));
const Registry = loadLibrary(path.join(__dirname, '..', 'modules/lockscreen/styles/LockStyleRegistry.js'));

test('tone selector is shown exactly for styles with more than one tone', () => {
    const entry = Lock.category.sections.flatMap(s => s.entries).find(e => e.key === 'lockscreen.tone');
    for (const style of Registry.styles) {
        const shown = SchemaUtil.evalCondition(entry.visibleWhen, k => (k === 'lockscreen.style' ? style.id : undefined));
        assert.equal(shown, style.tones.length > 1, style.id);
    }
});
