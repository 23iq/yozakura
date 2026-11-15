// Links between settings pages (editors/PageLink.qml entries) land on a
// section that has rows in the window (a section of advanced rows only
// would open the page with nothing to reveal), and on the named row.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const repo = path.join(__dirname, '..');
const SchemaUtil = loadLibrary(path.join(repo, 'modules/settings/SchemaUtil.js'));
const Categories = loadLibrary(path.join(repo, 'modules/settings/schema/Categories.js'));

test('every page link opens a section with window rows (and its row)', () => {
    let n = 0;
    for (const x of SchemaUtil.flatten(Categories.categories)) {
        const e = x.entry;
        if (e.component !== 'PageLink' || !e.targetSection)
            continue;
        n++;
        const cat = Categories.resolve(e.target);
        assert.ok(cat, `${e.id}: no page ${e.target}`);
        const sec = (cat.sections || []).find(s => s.id === e.targetSection);
        assert.ok(sec, `${e.id}: no section ${e.targetSection} on ${cat.id}`);
        const rows = sec.entries.filter(r => SchemaUtil.inWindow(r, sec));
        assert.ok(rows.length > 0, `${e.id}: ${cat.id}/${sec.id} has no window row`);
        if (e.targetEntry)
            assert.ok(rows.some(r => SchemaUtil.entryId(r) === e.targetEntry), `${e.id}: ${e.targetEntry} is not a row of ${sec.id}`);
    }
    assert.ok(n >= 3, `${n} page links`);
});
