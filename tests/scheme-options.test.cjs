const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const S = loadLibrary(path.join(__dirname, '../modules/widgets/dashboard/wallpapers/SchemeOptions.js'));
const plain = v => JSON.parse(JSON.stringify(v));

test('matugen schemes come first, then the colour presets', () => {
    const o = plain(S.options(['Nord'], k => k));
    assert.equal(o.length, 9);
    assert.deepEqual(o[0], { value: 'matugen:scheme-content', text: 'wallpapers.scheme_content' });
    assert.equal(o[3].text, 'wallpapers.scheme_fruit_salad');
    assert.deepEqual(o[8], { value: 'preset:Nord', text: 'Nord' });
});

test('a preset wins over the matugen scheme; values round-trip', () => {
    assert.equal(S.current('Nord', 'scheme-tonal-spot'), 'preset:Nord');
    assert.equal(S.current('', 'scheme-tonal-spot'), 'matugen:scheme-tonal-spot');
    assert.equal(S.current('', ''), '');
    assert.deepEqual(plain(S.parse('preset:My:Theme')), { kind: 'preset', id: 'My:Theme' });
    assert.equal(S.parse('bogus'), null);
});
