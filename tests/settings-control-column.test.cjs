// Settings card control column (modules/settings/ControlColumn.js): one
// width for every inline segmented / dropdown / slider / field of a card.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const CC = qmljs.loadLibrary(path.join(__dirname, '..', 'modules/settings/ControlColumn.js'));

const px = v => v;
// 8 px a character
const measure = s => String(s).length * 8;
const seg = labels => ({ type: 'selector', options: labels.map(l => ({ value: l, label: l })) });

test('switches, steppers and pictures need no column', () => {
    assert.equal(CC.need({ type: 'toggle' }, measure, px), 0);
    assert.equal(CC.need({ type: 'number' }, measure, px), 0);
    assert.equal(CC.need(Object.assign(seg(['a', 'b']), { display: 'cards' }), measure, px), 0);
    assert.equal(CC.need({ type: 'text', multiline: true }, measure, px), 0);
    assert.equal(CC.column([{ type: 'toggle' }, { type: 'number' }], measure, 500, px), 0);
});

test('a segmented needs equal segments of its longest label', () => {
    assert.equal(CC.need(seg(['Top', 'Bottom', 'Left', 'Right']), measure, px), 4 * (48 + 40));
    // past four options it is a dropdown as wide as its longest option
    assert.equal(CC.need(seg(['a', 'b', 'c', 'd', 'eeeeee']), measure, px), 48 + 100);
    assert.equal(CC.need(Object.assign(seg(['a', 'b', 'c']), { iconOnly: true }), measure, px), 3 * 44);
    // a glyph before each name widens every segment
    const iconSeg = { type: 'selector', options: ['Top', 'Left'].map(l => ({ value: l, label: l, icon: 'arrowUp' })) };
    assert.equal(CC.need(iconSeg, measure, px), 2 * (32 + 24 + 40));
});

test('the steppers of a card share the widest readout', () => {
    const text = (v, e) => String(v).length * 8 + (e.unit ? 8 * (e.unit.length + 1) : 0);
    const rows = [{ type: 'number', min: 1, max: 9 }, { type: 'number', min: 5, max: 240, unit: 'min' },
        { type: 'number', min: 0, max: 5, specialValues: [{ value: 0, label: 'x' }] }, { type: 'toggle' }];
    // "240 min"
    assert.equal(CC.readout(rows, text), 3 * 8 + 4 * 8);
    assert.equal(CC.readout([{ type: 'toggle' }], text), 0);
});

test('the column is the widest need, between 40 % and 80 % of the row', () => {
    const rows = [seg(['Top', 'Bottom', 'Left', 'Right']), seg(['Follow pin', 'Hover edge', 'Always']), { type: 'toggle' }];
    // widest: 3 * (80 + 40) = 360
    assert.equal(CC.column(rows, measure, 700, px), 360);
    // small needs take 40 %
    assert.equal(CC.column([seg(['a', 'b'])], measure, 500, px), 200);
    // beside short labels: 360 of 500 (4 * 8 + 360 + 88 = 480 fits)
    assert.equal(CC.column(rows.map(r => Object.assign({ label: 'Edge' }, r)), measure, 500, px), 360);
    // never past what the longest label of the column's rows leaves
    // (500 - 23 * 8 - 40 = 276)
    assert.equal(CC.column(rows.map(r => Object.assign({ label: 'A rather long row label' }, r)), measure, 500, px), 276);
    // a control that goes under its label (a long word) does not size it
    const wide = [Object.assign({ label: 'Extraordinarily' }, rows[0]), Object.assign({ label: 'Size' }, seg(['a', 'b']))];
    assert.equal(CC.column(wide, measure, 450, px), 180);
    // labels are translated before they are measured
    assert.equal(CC.column([Object.assign({ label: 'k' }, rows[0])], measure, 450, px, k => k === 'k' ? 'Extraordinarily' : k), 0);
});
