// Guard: animations in modules/**/*.qml take their easing and duration from
// the Motion tokens (modules/theme/Motion.qml), not from literals. Looping
// animations (Animation.Infinite / loops:) are effect-internal and exempt.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '../modules');

// file (relative to modules/) -> why its literals stay.
const ALLOW = {
    'components/surfaceeffects/CrtSurface.qml': 'CRT flicker timings are effect-internal',
    'settings/previews/TransitionPreview.qml': 'previews the wallpaper transition curves',
};

function walk(dir, out = []) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, e.name);
        if (e.isDirectory()) walk(p, out);
        else if (p.endsWith('.qml')) out.push(p);
    }
    return out;
}

const count = (s, c) => s.split(c).length - 1;

// Text of the enclosing blocks of line i (the line's own block included).
function enclosing(lines, i) {
    const blocks = [];
    let depth = 0;
    for (let j = i; j >= 0; j--) {
        const l = lines[j];
        if (j !== i) depth += count(l, '}') - count(l, '{');
        else if (/\{/.test(l)) blocks.push(j);
        if (j !== i && depth < 0) {
            blocks.push(j);
            depth = 0;
        }
    }
    return blocks.map(j => {
        let d = 0, txt = '';
        for (let k = j; k < lines.length; k++) {
            txt += lines[k] + '\n';
            d += count(lines[k], '{') - count(lines[k], '}');
            if (d <= 0 && txt.includes('{')) break;
        }
        return { head: lines[j], txt };
    });
}

const LITERAL = /\beasing\.type:.*\bEasing\.\w+|\bduration:\s*[1-9]\d*\b|\beasingType\b.*Easing\./;

function offenders(file) {
    const lines = fs.readFileSync(file, 'utf8').split('\n');
    const bad = [];
    lines.forEach((l, i) => {
        if (/^\s*\/\//.test(l) || !LITERAL.test(l)) return;
        const anim = enclosing(lines, i).filter(b => /(Animation|Animator)\b/.test(b.head));
        if (anim.length === 0) return;
        if (anim.some(b => /Animation\.Infinite|\bloops:/.test(b.txt))) return;
        bad.push(`${i + 1}: ${l.trim()}`);
    });
    return bad;
}

test('animations use Motion tokens, not literal easing or duration', () => {
    const problems = [];
    for (const f of walk(ROOT)) {
        const rel = path.relative(ROOT, f);
        if (ALLOW[rel]) continue;
        for (const b of offenders(f)) problems.push(`modules/${rel}:${b}`);
    }
    assert.deepEqual(problems, []);
});

test('the allowlist only names files that still need it', () => {
    for (const rel of Object.keys(ALLOW)) {
        const f = path.join(ROOT, rel);
        assert.ok(fs.existsSync(f), rel);
        assert.ok(/Easing\.|duration:\s*[1-9]/.test(fs.readFileSync(f, 'utf8')), `${rel} no longer has literals`);
    }
});
