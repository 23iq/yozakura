const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const O = loadLibrary(path.join(__dirname, '../modules/services/OcrLangs.js'));
const U = loadLibrary(path.join(__dirname, '../modules/settings/schema/updates.js'));
const D = loadLibrary(path.join(__dirname, '../config/defaults/system.js')).data;
const plain = v => JSON.parse(JSON.stringify(v));

test('OCR language codes match the settings chips and the defaults', () => {
    assert.deepEqual(plain(O.CODES), plain(U.OCR_KEYS));
    assert.deepEqual(Object.keys(D.ocr), plain(O.CODES));
});

test('every selected language is passed to tesseract, in chip order', () => {
    assert.equal(O.langs(D.ocr), 'eng+spa');
    assert.equal(O.langs({ eng: false, spa: false, rus: true }), 'rus');
    assert.equal(O.langs({ eng: true, spa: false, rus: true, kor: true }), 'eng+kor+rus');
    assert.equal(O.langs({ eng: false, spa: false }), 'eng');
    assert.equal(O.langs(null), 'eng+spa');
});
