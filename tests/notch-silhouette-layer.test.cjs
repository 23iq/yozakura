const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

// StyledRect carries its own layer.effect (Shadow / CornerMask, chosen from the
// corner style). The attached notch fill is only a texture for the mask
// MultiEffect: with the inherited effect swapping while the layer is live at
// shell start, the fill rendered as a thin strip until the notch resized.
test('attached notch fill drops the StyledRect layer effect', () => {
    const src = fs.readFileSync(path.join(__dirname, '..', 'modules/notch/NotchSilhouette.qml'), 'utf8');
    const block = src.slice(src.indexOf('id: attachedBg'), src.indexOf('MultiEffect {'));
    assert.match(block, /layer\.enabled: root\.attached/);
    assert.match(block, /layer\.effect: null/);
});
