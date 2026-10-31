// The lock screen draws with the kit's tokens: no raw font sizes, no theme
// font-size steps, no raw animation durations and no hand-made spinners.
// Screen-proportional hero clocks (digitSize * k) and the terminal style's
// mono size (theme.monoFontSize) are the only computed text sizes.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const dir = path.join(__dirname, '../modules/lockscreen');
const files = [...fs.readdirSync(dir).map(f => path.join(dir, f)), ...fs.readdirSync(path.join(dir, 'styles')).map(f => path.join(dir, 'styles', f))].filter(f => f.endsWith('.qml'));

function offending(re) {
    const out = [];
    for (const f of files) {
        fs.readFileSync(f, 'utf8').split('\n').forEach((line, i) => {
            if (re.test(line))
                out.push(`${path.relative(dir, f)}:${i + 1}: ${line.trim()}`);
        });
    }
    return out;
}

test('no raw font sizes or theme font-size steps', () => {
    assert.deepEqual(offending(/pixelSize:\s*\d+\s*$/), []);
    assert.deepEqual(offending(/Styling\.fontSize\(/), []);
});

test('no raw animation durations', () => {
    assert.deepEqual(offending(/duration:\s*\d+\s*$/), []);
});

test('the submit spinner is the shared LockSpinner', () => {
    assert.deepEqual(offending(/Icons\.circleNotch/).filter(l => !l.startsWith('LockSpinner.qml')), []);
});

test('every style file that sizes things imports the kit', () => {
    for (const f of files) {
        const src = fs.readFileSync(f, 'utf8');
        if (/\b(Space|Type)\.\w/.test(src))
            assert.match(src, /import qs\.modules\.components\.kit/, path.relative(dir, f));
    }
});
