const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const cava = {};
const file = path.join(__dirname, '../modules/services/CavaVisualizer.js');
if (fs.existsSync(file)) vm.runInNewContext(fs.readFileSync(file, 'utf8').replace(/^\.pragma library\s*/, ''), cava);

test('config requests raw ascii mono frames on stdout', () => {
    assert.equal(typeof cava.buildConfig, 'function');
    const conf = cava.buildConfig(24, 60);
    for (const line of ['bars = 24', 'framerate = 60', 'method = raw', 'raw_target = /dev/stdout', 'data_format = ascii', 'ascii_max_range = 1000', 'bar_delimiter = 59', 'frame_delimiter = 10', 'channels = mono'])
        assert.ok(conf.split('\n').includes(line), line);
});
test('frames normalize to 0..1 and reject torn or malformed lines', () => {
    assert.deepEqual(Array.from(cava.parseFrame('0;500;1000;', 3)), [0, 0.5, 1]);
    assert.deepEqual(Array.from(cava.parseFrame('2000;-5;', 2)), [1, 0]);
    for (const line of ['0;500;', '', 'a;b;c;', null]) assert.equal(cava.parseFrame(line, 3), null);
});
test('resampling keeps bar count and range', () => {
    const src = [0, 0.2, 1, 0.4, 0.1, 0.3];
    assert.deepEqual(Array.from(cava.resample(src, 3)), [0.2, 1, 0.3]);
    assert.deepEqual(Array.from(cava.resample(src, 6)), src);
    const wide = cava.resample(src, 11);
    assert.equal(wide.length, 11);
    assert.equal(wide[0], 0);
    assert.equal(wide[10], 0.3);
    assert.ok(Array.from(wide).every(v => v >= 0 && v <= 1));
    assert.deepEqual(Array.from(cava.resample([], 4)), [0, 0, 0, 0]);
});
test('readFrame returns the current array for a repeated frame and a new one otherwise', () => {
    const a = cava.readFrame('0;500;1000;', 3, null);
    assert.deepEqual(Array.from(a), [0, 0.5, 1]);
    assert.equal(cava.readFrame('0;500;1000;\n', 3, a), a);
    const b = cava.readFrame('0;500;999;', 3, a);
    assert.notEqual(b, a);
    assert.deepEqual(Array.from(a), [0, 0.5, 1], 'the previous frame is never mutated');
    assert.deepEqual(Array.from(b), [0, 0.5, 0.999]);
    // A different length is a different frame.
    assert.notEqual(cava.readFrame('0;500;', 0, a), a);
    for (const line of ['0;500;', '', ';', '1;;2;', '1;x;2;', null]) assert.equal(cava.readFrame(line, 3, a), null, String(line));
});
test('parseFrame keeps the old parseInt results for cava output', () => {
    assert.deepEqual(Array.from(cava.parseFrame('  12;0;1000  ', 3)), [0.012, 0, 1]);
    assert.deepEqual(Array.from(cava.parseFrame('+7;-0;', 2)), [0.007, 0]);
    assert.equal(cava.parseFrame('1;2;3;4;', 3), null);
});
test('the visualizer rate (performance.visualizerFps) is clamped to 15..60, default 30', () => {
    assert.equal(cava.clampRate(30), 30);
    assert.equal(cava.clampRate(20), 20);
    assert.equal(cava.clampRate(5), 15);
    assert.equal(cava.clampRate(240), 60);
    assert.equal(cava.clampRate(24.6), 25);
    assert.equal(cava.clampRate('45'), 45);
    for (const broken of [undefined, null, '', 'x', 0, -10, NaN, Infinity])
        assert.equal(cava.clampRate(broken), 30, String(broken));
});
