// modules/settings/ConfigWrite.js: one dotted key written into Config the way the
// settings window does it (SettingsStore.set) and the main shell applies a
// separate window's relayed preview (PreviewSink.qml).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const W = loadLibrary(path.join(__dirname, '../modules/settings/ConfigWrite.js'));
const SchemaUtil = loadLibrary(path.join(__dirname, '../modules/settings/SchemaUtil.js'));
const plain = v => JSON.parse(JSON.stringify(v));

// A Config stand-in: JsonObject children carry objectName, `var` props are plain.
function config() {
    return {
        bar: { objectName: '', position: 'top', layout: { style: { pill: true, gap: 4 } } },
        ai: { objectName: '', quickAsk: { objectName: '', enabled: false, model: 'a' } },
        theme: { objectName: '', roundness: 8 }
    };
}

test('assign: plain, nested JsonObject and var-object keys', () => {
    const c = config();
    const staged = [];
    assert.equal(W.assign(c, 'bar.position', 'bottom', d => staged.push(d)), 'bar');
    assert.equal(c.bar.position, 'bottom');
    // a JsonObject child is assigned in place
    const qa = c.ai.quickAsk;
    assert.equal(W.assign(c, 'ai.quickAsk.enabled', true, d => staged.push(d)), 'ai');
    assert.equal(c.ai.quickAsk, qa);
    assert.equal(qa.enabled, true);
    // a `var` object on the way is replaced by an updated copy
    const before = c.bar.layout;
    W.assign(c, 'bar.layout.style.gap', 8, d => staged.push(d));
    assert.notEqual(c.bar.layout, before);
    assert.deepEqual(plain(c.bar.layout), { style: { pill: true, gap: 8 } });
    assert.deepEqual(before.style.gap, 4, 'the old object is not mutated');
    assert.deepEqual(staged, ['bar', 'ai', 'bar'], 'stage runs before every write');
});

test('assign: lists are copied, unknown domains refused', () => {
    const c = config();
    const list = [{ a: 1 }];
    W.assign(c, 'theme.roundness', list);
    list[0].a = 2;
    assert.deepEqual(plain(c.theme.roundness), [{ a: 1 }]);
    let staged = 0;
    assert.equal(W.assign(c, 'nope.key', 1, () => staged++), '');
    assert.equal(W.assign(c, 'bar', 1, () => staged++), '');
    assert.equal(W.assign(null, 'bar.position', 1), '');
    assert.equal(staged, 0, 'nothing is staged for a refused key');
});

test('SchemaUtil re-exports the same path helpers', () => {
    assert.deepEqual(plain(SchemaUtil.splitKey('bar.layout.style')), { domain: 'bar', prop: 'layout', path: ['layout', 'style'] });
    assert.deepEqual(plain(SchemaUtil.withPath({ a: { b: 1 } }, ['a', 'c'], 2)), { a: { b: 1, c: 2 } });
    assert.equal(SchemaUtil.getPath({ a: { b: 3 } }, ['a', 'b']), 3);
    assert.deepEqual(plain(SchemaUtil.plain([1, 2])), [1, 2]);
});
