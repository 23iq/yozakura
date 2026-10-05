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
