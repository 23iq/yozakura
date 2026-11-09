const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const m = qmljs.loadLibrary(path.join(__dirname, '../modules/widgets/dashboard/metrics/MetricsModel.js'));

test('seriesColor: one palette colour per kind, GPUs by vendor', () => {
    assert.equal(m.seriesColor('cpu'), 'red');
    assert.equal(m.seriesColor('ram'), 'cyan');
    assert.equal(m.seriesColor('disk'), 'yellow');
    assert.equal(m.seriesColor('gpu', 'NVIDIA'), 'green');
    assert.equal(m.seriesColor('gpu', 'amd'), 'red');
    assert.equal(m.seriesColor('gpu', 'intel'), 'blue');
    assert.equal(m.seriesColor('gpu', ''), 'magenta');
    assert.equal(m.seriesColor('gpu', undefined), 'magenta');
});

test('diskGlyph, capitalize, memoryText', () => {
    assert.equal(m.diskGlyph('ssd'), 'ssd');
    assert.equal(m.diskGlyph('hdd'), 'hdd');
    assert.equal(m.diskGlyph('unknown'), 'disk');
    assert.equal(m.capitalize('archbox'), 'Archbox');
    assert.equal(m.capitalize(''), '');
    assert.equal(m.memoryText(15938355, 32505856), '15.2 GB / 31.0 GB');
    assert.equal(m.memoryText(0, 0), '0.0 GB / 0.0 GB');
});

test('osLogo: exact, partial, Linux fallback, none without logos', () => {
    const logos = { 'Arch Linux': 'A', NixOS: 'N', Linux: 'L' };
    assert.equal(m.osLogo('NixOS', logos), 'N');
    assert.equal(m.osLogo('NixOS 25.11 (Xantusia)', logos), 'N');
    assert.equal(m.osLogo('Gentoo', logos), 'L');
    assert.equal(m.osLogo('', logos), 'L');
    assert.equal(m.osLogo('NixOS', null), '');
    assert.equal(m.osLogo('Gentoo', { NixOS: 'N' }), '');
});

test('chartWindow: zoom sets the visible samples, newest on the right edge', () => {
    const w = m.chartWindow(490, 1, 120, 120);
    assert.equal(w.maxPoints, 50);
    assert.equal(w.points, 50);
    assert.equal(w.spacing, 10);
    assert.equal(w.offset, 0);
    assert.equal(w.start, 70);
    // Short history: right aligned
    const s = m.chartWindow(490, 1, 5, 5);
    assert.equal(s.points, 5);
    assert.equal(s.offset, 490 - 40);
    // Zoomed in hard: never fewer than 10 samples
    assert.equal(m.chartWindow(90, 10, 100, 100).maxPoints, 10);
    assert.equal(m.chartWindow(490, 0.2, 300, 300).maxPoints, 250);
});

test('gridLines: every 10 absolute samples, inside the window', () => {
    const w = m.chartWindow(490, 1, 120, 125);
    const xs = m.gridLines(w, 125);
    // start 75: lines at absolute 80, 90 .. 120 -> visible 5, 15 .. 45
    assert.deepEqual(Array.from(xs), [50, 150, 250, 350, 450]);
});

test('stepInterval and clampZoom', () => {
    assert.equal(m.stepInterval(2000, 1), 2100);
    assert.equal(m.stepInterval(100, -1), 100);
    assert.equal(m.stepInterval(150, -1), 100);
    assert.equal(m.clampZoom(5), 3);
    assert.equal(m.clampZoom(0.05), 0.2);
    assert.equal(m.clampZoom(1.25), 1.25);
    assert.equal(m.clampZoom(undefined), 1);
});
