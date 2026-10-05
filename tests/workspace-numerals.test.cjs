const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const N = loadLibrary(path.join(__dirname, '../modules/bar/workspaces/WorkspaceNumerals.js'));
const validator = loadLibrary(path.join(__dirname, '../config/ConfigValidator.js'));
const defaults = JSON.parse(JSON.stringify(loadLibrary(path.join(__dirname, '../config/defaults/workspaces.js')).data));

test('registry: arabic is the default and unknown ids fall back to it', () => {
    assert.equal(N.DEFAULT_ID, 'arabic');
    assert.deepEqual([...N.ids()], ['arabic', 'kanji', 'roman']);
    assert.equal(N.isValid('kanji'), true);
    assert.equal(N.isValid('klingon'), false);
    assert.equal(N.get('klingon').id, 'arabic');
    assert.equal(N.get(undefined).id, 'arabic');
    assert.equal(N.format('klingon', 7), '7');
});

test('every system has the fields the label relies on', () => {
    for (const id of N.ids()) {
        const s = N.get(id);
        assert.equal(typeof s.label, 'string');
        assert.equal(typeof s.format, 'function');
        if (s.fit) for (const k of ['em', 'width', 'height', 'condense']) assert.ok(s.fit[k] > 0 && s.fit[k] <= 1, id + '.' + k);
        if (s.font) {
            assert.ok(Array.isArray(s.font.bundled) && Array.isArray(s.font.prefer) && Array.isArray(s.font.avoid || []));
            assert.equal(typeof s.font.lang, 'string');
        }
    }
});

test('arabic', () => {
    assert.equal(N.format('arabic', 1), '1');
    assert.equal(N.format('arabic', 10), '10');
    assert.equal(N.format('arabic', 123), '123');
});

test('kanji: units, tens and hundreds', () => {
    const cases = {
        1: '一', 2: '二', 3: '三', 4: '四', 5: '五', 6: '六', 7: '七', 8: '八', 9: '九', 10: '十',
        11: '十一', 12: '十二', 19: '十九', 20: '二十', 21: '二十一', 30: '三十', 99: '九十九',
        100: '百', 101: '百一', 110: '百十', 111: '百十一', 120: '百二十', 200: '二百', 305: '三百五',
        999: '九百九十九', 1000: '千', 1001: '千一', 2024: '二千二十四', 9999: '九千九百九十九',
        10000: '一万', 10001: '一万一', 20000: '二万', 123456: '十二万三千四百五十六', 99999999: '九千九百九十九万九千九百九十九',
    };
    for (const [n, text] of Object.entries(cases)) assert.equal(N.format('kanji', Number(n)), text, n);
});

test('kanji never repeats 一 before 十/百/千', () => {
    for (let n = 1; n < 10000; n++) assert.doesNotMatch(N.format('kanji', n), /^一[十百千]|[^万]一[十百千]/, String(n));
});

test('roman: standard subtractive forms', () => {
    const cases = { 1: 'I', 2: 'II', 3: 'III', 4: 'IV', 5: 'V', 9: 'IX', 10: 'X', 14: 'XIV', 19: 'XIX', 20: 'XX',
        40: 'XL', 49: 'XLIX', 90: 'XC', 400: 'CD', 944: 'CMXLIV', 1994: 'MCMXCIV', 3999: 'MMMCMXCIX' };
    for (const [n, text] of Object.entries(cases)) assert.equal(N.format('roman', Number(n)), text, n);
});

test('out-of-range values fall back to arabic digits', () => {
    for (const id of ['kanji', 'roman']) {
        assert.equal(N.format(id, 0), '0');
        assert.equal(N.format(id, -3), '-3');
        assert.equal(N.format(id, 2.5), '2.5');
        assert.equal(N.format(id, NaN), 'NaN');
    }
    assert.equal(N.format('roman', 4000), '4000');
    assert.equal(N.format('kanji', 100000000), '100000000');
});

test('glyph coverage of bundled subsets', () => {
    const coverage = N.get('kanji').font.bundled[0].coverage;
    for (let n = 1; n <= 99999; n++) assert.ok(N.covers(coverage, N.format('kanji', n)), String(n));
    assert.equal(N.covers(coverage, N.format('kanji', 100000000)), false);
    assert.equal(N.covers(coverage, ''), false);
    assert.equal(N.covers('', '一'), false);
});

test('font probe: first existing bundled file and the preferred system family', () => {
    const { prefer, avoid } = N.get('kanji').font;
    const probe = out => ({ ...N.parseFontProbe(out, prefer, avoid) });
    const out = [
        'file:/shell/assets/fonts/workspaces/kanji.subset.ttf',
        'Noto Sans CJK TC,Noto Sans CJK TC Medium',
        'Noto Serif CJK JP,Noto Serif CJK JP Light',
        'Noto Sans CJK JP,Noto Sans CJK JP Black',
        'Noto Serif CJK KR',
        '',
    ].join('\n');
    assert.deepEqual(probe(out), { bundledFile: '/shell/assets/fonts/workspaces/kanji.subset.ttf', systemFamily: 'Noto Sans CJK JP' });
    assert.equal(probe('Noto Sans CJK KR\nNoto Sans CJK JP').systemFamily, 'Noto Sans CJK JP');
    assert.equal(probe('IPAexGothic\nIPAexMincho').systemFamily, 'IPAexGothic');
    assert.deepEqual(probe(''), { bundledFile: '', systemFamily: '' });
});

test('kanji never picks a serif/mincho family by default', () => {
    const { prefer, avoid } = N.get('kanji').font;
    const pick = out => N.parseFontProbe(out, prefer, avoid).systemFamily;
    assert.equal(pick('Noto Serif CJK JP\nIPAexMincho\nShippori Mincho B1'), '');
    // A name matching both lists is still avoided.
    assert.equal(pick('Fancy Gothic Serif'), '');
    // Families matching no preferred fragment fall through to the theme font.
    assert.equal(pick('Some Random JP Font'), '');
    assert.ok(N.get('kanji').font.weight >= 700, 'kanji auto font is heavy');
});

test('optical fit: short labels keep size, long ones condense then shrink', () => {
    const fit = { em: 1, width: 0.6, height: 0.5, condense: 0.7 };
    assert.deepEqual({ ...N.fitLabel(fit, 10, 10, 30) }, { scale: 1, condense: 1 });
    // Too tall: scaled to the height cap.
    assert.equal(N.fitLabel(fit, 10, 30, 30).scale, 0.5);
    // A bit too wide: condensed only.
    const c = N.fitLabel(fit, 20, 10, 30);
    assert.equal(c.scale, 1);
    assert.ok(Math.abs(20 * c.condense - 18) < 1e-9);
    // Far too wide: condensed to the limit, then scaled to fit exactly.
    const w = N.fitLabel(fit, 60, 10, 30);
    assert.equal(w.condense, 0.7);
    assert.ok(Math.abs(60 * w.scale * w.condense - 18) < 1e-9);
    for (const [iw, ih] of [[5, 5], [40, 12], [90, 30], [0, 0]]) {
        const r = N.fitLabel(fit, iw, ih, 30);
        assert.ok(iw * r.scale * r.condense <= 18 + 1e-9 && ih * r.scale <= 15 + 1e-9, `${iw}x${ih}`);
    }
});

test('config: defaults and validation against the registry', () => {
    assert.equal(defaults.numeralStyle, N.DEFAULT_ID);
    assert.equal(defaults.numeralFont, '');
    const v = raw => JSON.parse(JSON.stringify(validator.validate(raw, defaults)));
    for (const id of N.ids()) assert.equal(v({ numeralStyle: id }).numeralStyle, id);
    assert.equal(v({ numeralStyle: 'wat' }).numeralStyle, 'arabic');
    assert.equal(v({ numeralStyle: 3 }).numeralStyle, 'arabic');
    assert.equal(v({}).numeralStyle, 'arabic');
    assert.equal(v({ numeralFont: 'Noto Serif CJK JP' }).numeralFont, 'Noto Serif CJK JP');
    // Unrelated keys with the same validator path are untouched.
    assert.equal(v({ showNumbers: true, numeralStyle: 'kanji' }).showNumbers, true);
});
