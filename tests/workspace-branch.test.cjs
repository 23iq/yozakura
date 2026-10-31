const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const geo = loadLibrary(path.join(__dirname, '../modules/bar/workspaces/branch/BranchGeometry.js'));
const styles = loadLibrary(path.join(__dirname, '../modules/bar/workspaces/indicators/IndicatorStyles.js'));
const urgency = loadLibrary(path.join(__dirname, '../modules/bar/workspaces/WorkspaceUrgency.js'));
const plain = v => JSON.parse(JSON.stringify(v));

// Numbers of an SVG path, as [x, y] pairs.
function points(d) {
    const nums = (d.match(/-?\d+(\.\d+)?/g) || []).map(Number);
    const out = [];
    for (let i = 0; i + 1 < nums.length; i += 2)
        out.push([nums[i], nums[i + 1]]);
    return out;
}

test('branch is registered as a strip style, the default stays the pill', () => {
    assert.equal(styles.DEFAULT_ID, 'pill');
    assert.ok(styles.isValid('branch'));
    assert.equal(styles.strip('pill'), '');
    assert.match(styles.strip('branch'), /BranchStrip\.qml$/);
    assert.equal(styles.filled('branch'), false);
});

test('stripSlots reads ids, window counts, urgency and the active workspace', () => {
    const windows = { 1: [{}, {}], 3: [{}] };
    const slots = styles.stripSlots(3, i => i + 1, windows, { 3: true }, 2);
    assert.deepEqual(plain(slots.map(s => [s.id, s.windows, s.urgent, s.active])),
        [[1, 2, false, false], [2, 0, false, true], [3, 1, true, false]]);
    assert.equal(styles.stripSlots(0, i => i, {}, {}, 1).length, 0);
    assert.equal(styles.stripSlots(1, () => 9, null, null, 9)[0].windows, 0);
});

test('node: bud when empty, a petal per window (capped), active fully open', () => {
    assert.deepEqual(plain(geo.node({ windows: 0 })), { kind: 'bud', petals: 0, urgent: false, scale: 0 });
    assert.equal(geo.node({ windows: 2 }).kind, 'blossom');
    assert.equal(geo.node({ windows: 2 }).petals, 2);
    assert.equal(geo.node({ windows: 12 }).petals, geo.MAX_PETALS);
    const open = geo.node({ windows: 0, active: true });
    assert.equal(open.kind, 'open');
    assert.equal(open.petals, geo.MAX_PETALS);
    assert.equal(open.scale, 1);
    assert.ok(geo.node({ windows: 1 }).scale < 1);
    assert.equal(geo.node({ windows: 1, urgent: true }).urgent, true);
    assert.equal(geo.node(null).kind, 'bud');
});

test('a petal falls only when the same workspace lost a window', () => {
    assert.ok(geo.petalFalls({ id: 2, windows: 3 }, { id: 2, windows: 2 }));
    assert.ok(!geo.petalFalls({ id: 2, windows: 2 }, { id: 2, windows: 3 }));
    assert.ok(!geo.petalFalls({ id: 2, windows: 3 }, { id: 4, windows: 1 }), 'slot reused by another workspace');
    assert.ok(!geo.petalFalls(null, { id: 2, windows: 1 }));
});

test('unknown shapes and roles fall back to the first entry', () => {
    assert.equal(geo.shape('tulip'), 'sakura');
    assert.equal(geo.shape('leaf'), 'leaf');
    assert.equal(geo.role('pink'), 'primary');
    assert.equal(geo.role('tertiary'), 'tertiary');
});

test('the branch stays inside the strip in both orientations', () => {
    const slot = 28;
    for (const count of [1, 3, 7, 10]) {
        for (const vertical of [false, true]) {
            const d = geo.branchPath(count, slot, vertical);
            assert.match(d, /^M.*Z$/);
            for (const [x, y] of points(d)) {
                const along = vertical ? y : x, across = vertical ? x : y;
                assert.ok(along >= 0 && along <= count * slot, `${count}/${vertical}: along ${along}`);
                assert.ok(across >= 0 && across <= slot, `${count}/${vertical}: across ${across}`);
            }
        }
    }
    assert.equal(geo.branchPath(0, 28, false), '');
    assert.equal(geo.branchPath(3, 0, false), '');
});

test('node centres sit in their slots, swapped on vertical strips', () => {
    const slot = 30;
    for (let i = 0; i < 8; i++) {
        const h = geo.centre(i, slot, false), v = geo.centre(i, slot, true);
        assert.equal(h.x, (i + 0.5) * slot);
        assert.ok(Math.abs(h.y - slot / 2) < slot * 0.1);
        assert.deepEqual(plain(v), { x: h.y, y: h.x });
    }
});

test('the branch tapers from the trunk to a fine tip', () => {
    const slot = 28;
    assert.ok(geo.width(0.1, slot) > geo.width(0.9, slot));
    assert.ok(geo.width(1, slot) >= 0.6 * 0.6);
});

test('every blossom shape draws one closed outline per petal within the bloom', () => {
    const len = geo.bloomRadius(28), c = 14;
    for (const shape of geo.SHAPES) {
        for (const n of [1, 3, 5]) {
            const d = geo.petalsPath(shape, 2, 0, n, c, c, len);
            assert.equal((d.match(/Z/g) || []).length, n, `${shape} ${n}`);
            for (const [x, y] of points(d))
                assert.ok(Math.hypot(x - c, y - c) <= len * 1.15, `${shape}: control point near the bloom`);
        }
        assert.equal(geo.petalsPath(shape, 0, 5, 5, c, c, len), '');
    }
    assert.match(geo.budPath(1, c, c, 5), /^M.*Z$/);
});

test('petal positions are spread around the flower', () => {
    const step = 360 / geo.MAX_PETALS;
    for (let p = 1; p < geo.MAX_PETALS; p++)
        assert.ok(Math.abs(geo.petalAngle(3, p) - geo.petalAngle(3, p - 1) - step) < 1e-9);
});

test('a falling petal drifts down and turns', () => {
    const f = geo.fall(3, 28);
    assert.ok(f.dy > 0);
    assert.ok(Math.abs(f.dx) > 0 && Math.abs(f.dx) < 28);
    assert.ok(f.turn > 0);
});

test('urgency: windows, tags and Hyprland urgent events', () => {
    const wins = [
        { address: '0xAB', workspace: { id: 2 } },
        { address: '0xcd', workspace: { id: 3 }, urgent: true },
    ];
    assert.deepEqual(plain(urgency.map(wins, [], {})), { 3: true });
    assert.deepEqual(plain(urgency.map([], [5], {})), { 5: true });
    let set = urgency.onEvent({}, 'urgent', 'ab');
    assert.deepEqual(plain(urgency.map(wins, [], set)), { 2: true, 3: true });
    set = urgency.onEvent(set, 'activewindowv2', 'ab');
    assert.deepEqual(plain(set), {});
    set = urgency.onEvent(urgency.onEvent({}, 'urgent', 'ab'), 'closewindow', '0xab');
    assert.deepEqual(plain(set), {});
    assert.deepEqual(plain(urgency.onEvent({ x: true }, "workspacev2", "1")), { x: true });
    assert.deepEqual(plain(urgency.map(null, null, null)), {});
});

test('urgency stays readable: alert role when it contrasts, else ink', () => {
    const c = (r, g, b) => ({ r, g, b });
    const white = c(1, 1, 1), black = c(0, 0, 0);
    const pink = c(1, 0.71, 0.67), darkBg = c(0.1, 0.07, 0.07);
    assert.ok(Math.abs(geo.contrast(white, black) - 21) < 1e-9);
    // error on a dark bar: readable, kept
    assert.equal(geo.readable(pink, darkBg, white, black), pink);
    // error close to its ground (pink blossom): falls back to the better ink
    assert.equal(geo.readable(pink, pink, white, black), black);
    assert.equal(geo.readable(pink, c(0.1, 0.1, 0.1), pink, black), pink);
    assert.ok(geo.haloRadius(30) + geo.haloWidth(30) / 2 <= 15);
});
