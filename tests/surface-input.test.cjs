const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const S = loadLibrary(path.join(__dirname, '..', 'modules/components/SurfaceInput.js'));

test('release commits the input method before dropping focus', () => {
    const order = [];
    const field = {
        set focus(v) {
            order.push('focus:' + v);
        },
    };
    S.release({ commit: () => order.push('commit') }, field);
    assert.deepStrictEqual(order, ['commit', 'focus:false']);
});

test('release tolerates no focused item and no input method', () => {
    assert.doesNotThrow(() => S.release(null, null));
    assert.doesNotThrow(() => S.release({}, null));
});
