const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const M = loadLibrary(path.join(__dirname, '../modules/shell/LayoutModel.js'));
const plain = (v) => JSON.parse(JSON.stringify(v));

const EDGES = ['top', 'bottom', 'left', 'right'];
const cfg = (o = {}) => ({
    bar: Object.assign({ position: 'top', layout: { style: 'classic' }, panels: [] }, o.bar || {}),
    notch: Object.assign({ enabled: true, position: 'top', align: 'center', style: 'attached' }, o.notch || {}),
    dock: Object.assign({ enabled: true, position: 'bottom', theme: 'default' }, o.dock || {})
});
const layoutOf = (bar, notch, dock) => M.fromConfig(cfg({
    bar: { layout: { style: bar ? 'classic' : 'none' } },
    notch: { enabled: notch },
    dock: { enabled: dock }
}));
const combos = [];
for (const bar of [true, false]) for (const notch of [true, false]) for (const dock of [true, false])
    combos.push([bar, notch, dock]);
const apply = (c, writes) => {
    const out = plain(c);
    for (const w of writes) {
        const parts = w.key.split('.');
        let t = out;
        for (let i = 0; i < parts.length - 1; i++) t = t[parts[i]] = t[parts[i]] || {};
        t[parts[parts.length - 1]] = plain(w.value);
    }
    return out;
};

test('fromConfig reads the existing keys of every part', () => {
    const l = plain(M.fromConfig(cfg({ notch: { position: 'bottom', align: 'end', style: 'pill' }, dock: { position: 'left', theme: 'floating' } })));
    assert.deepEqual(l.bar, { enabled: true, edge: 'top', style: 'classic', align: 'fill' });
    assert.deepEqual(l.notch, { enabled: true, edge: 'bottom', style: 'pill', align: 'end' });
    assert.deepEqual(l.dock, { enabled: true, edge: 'left', style: 'floating', align: 'center' });
});

test('the bar is off for style none, a missing config, or only disabled panels', () => {
    assert.equal(M.fromConfig(cfg({ bar: { layout: { style: 'none' } } })).bar.enabled, false);
    assert.equal(M.fromConfig(cfg({ bar: { panels: [{ id: 'a', edge: 'left', style: 'classic', enabled: false }] } })).bar.enabled, false);
    const p = M.fromConfig(cfg({ bar: { panels: [{ id: 'a', edge: 'left', style: 'classic', enabled: false }, { id: 'b', edge: 'right', style: 'islands', align: 'center' }] } })).bar;
    assert.deepEqual(plain(p), { enabled: true, edge: 'right', style: 'islands', align: 'center' });
    const empty = plain(M.fromConfig({}));
    assert.equal(empty.notch.enabled, true);
    assert.equal(empty.bar.enabled, true);
});

test('every content id has a home in every on/off combination', () => {
    for (const [bar, notch, dock] of combos) {
        const l = layoutOf(bar, notch, dock);
        for (const id of M.CONTENT) {
            const home = M.homeOf(id, l);
            assert.ok(['bar', 'notch', 'corner'].includes(home), `${id} ${bar}/${notch}/${dock}: ${home}`);
            if (home !== 'corner') assert.equal(l[home].enabled, true, `${id} homed in a disabled ${home}`);
        }
    }
});

test('re-homing rules', () => {
    for (const dock of [true, false]) {
        assert.equal(M.homeOf('activities', layoutOf(true, true, dock)), 'notch');
        assert.equal(M.homeOf('activities', layoutOf(true, false, dock)), 'bar');
        assert.equal(M.homeOf('activities', layoutOf(false, false, dock)), 'corner');
        assert.equal(M.homeOf('activities', layoutOf(false, true, dock)), 'notch');
        assert.equal(M.homeOf('clock', layoutOf(true, true, dock)), 'bar');
        assert.equal(M.homeOf('tray', layoutOf(false, true, dock)), 'notch');
        assert.equal(M.homeOf('clock', layoutOf(false, false, dock)), 'corner');
    }
    assert.equal(M.homeOf('nope', layoutOf(true, true, true)), '');
});

test('notch segments and corner content follow the homes', () => {
    assert.deepEqual(plain(M.notchSegments(layoutOf(false, true, true))), ['clock', 'tray']);
    assert.deepEqual(plain(M.notchSegments(layoutOf(true, true, true))), []);
    assert.deepEqual(plain(M.cornerContent(layoutOf(false, false, true))), ['activities', 'clock', 'tray']);
    assert.deepEqual(plain(M.cornerContent(layoutOf(true, false, false))), []);
});

test('activity presentation: configured off stays off, otherwise it follows the home', () => {
    assert.equal(M.activityPresentation(layoutOf(true, true, true), 'notch'), 'notch');
    assert.equal(M.activityPresentation(layoutOf(true, true, true), 'islands'), 'islands');
    assert.equal(M.activityPresentation(layoutOf(true, false, true), 'notch'), 'islands');
    assert.equal(M.activityPresentation(layoutOf(false, false, true), 'notch'), 'corner');
    assert.equal(M.activityPresentation(layoutOf(false, false, true), 'off'), 'off');
    const side = M.fromConfig(cfg({ bar: { position: 'left' }, notch: { enabled: false } }));
    assert.equal(M.homeOf('activities', side), 'bar');
    assert.equal(M.activityPresentation(side, 'notch'), 'corner');
    assert.deepEqual(plain(M.cornerContent(side)), ['activities']);
});

test('parts on one edge stack bar, dock, notch from the screen edge in', () => {
    for (const [bar, notch, dock] of combos) for (const e of EDGES) {
        const l = M.fromConfig(cfg({
            bar: { position: e, layout: { style: bar ? 'classic' : 'none' } },
            notch: { enabled: notch, position: e === 'left' || e === 'right' ? 'top' : e },
            dock: { enabled: dock, position: e }
        }));
        const s = plain(M.stacking(l));
        const all = [].concat(...EDGES.map((x) => s[x]));
        assert.deepEqual(all.sort(), plain(M.PARTS).filter((p) => l[p].enabled).sort());
        for (const x of EDGES) {
            const order = s[x].map((p) => M.PARTS.indexOf(p));
            assert.deepEqual(order, order.slice().sort(), `${x}: ${s[x]}`);
            s[x].forEach((p, i) => assert.equal(M.depthOf(p, l), i));
        }
    }
    assert.equal(M.depthOf('bar', layoutOf(false, true, true)), -1);
});

test('edges, styles and aligns offered per part', () => {
    assert.deepEqual(plain(M.edgesOf('bar')), EDGES);
    assert.deepEqual(plain(M.edgesOf('notch')), ['top', 'bottom']);
    assert.ok(M.stylesOf('bar').includes('islands') && !M.stylesOf('bar').includes('none'));
    assert.deepEqual(plain(M.stylesOf('notch')), ['attached', 'island', 'pill']);
    assert.deepEqual(plain(M.stylesOf('dock')), ['default', 'floating', 'integrated']);
    assert.deepEqual(plain(M.alignsOf('notch')), ['start', 'center', 'end']);
    assert.deepEqual(plain(M.alignsOf('dock')), []);
    assert.ok(M.alignsOf('bar').includes('fill'));
    assert.equal(M.canDrop('notch', 'left'), false);
    assert.equal(M.canDrop('bar', 'left'), true);
    assert.equal(M.canDrop('bogus', 'top'), false);
});

test('edits write only existing keys: legacy bar, notch and dock', () => {
    const c = cfg();
    assert.deepEqual(plain(M.edit(c, 'bar', 'edge', 'left')), [{ key: 'bar.position', value: 'left' }]);
    assert.deepEqual(plain(M.edit(c, 'bar', 'style', 'islands')), [{ key: 'bar.layout.style', value: 'islands' }]);
    assert.deepEqual(plain(M.edit(c, 'bar', 'enabled', false)), [{ key: 'bar.layout.style', value: 'none' }]);
    const off = cfg({ bar: { layout: { style: 'none' } } });
    assert.deepEqual(plain(M.edit(off, 'bar', 'enabled', true)), [{ key: 'bar.layout.style', value: 'classic' }]);
    assert.deepEqual(plain(M.edit(c, 'notch', 'enabled', false)), [{ key: 'notch.enabled', value: false }]);
    assert.deepEqual(plain(M.edit(c, 'notch', 'edge', 'bottom')), [{ key: 'notch.position', value: 'bottom' }]);
    assert.deepEqual(plain(M.edit(c, 'notch', 'edge', 'left')), []);
    assert.deepEqual(plain(M.edit(c, 'notch', 'align', 'start')), [{ key: 'notch.align', value: 'start' }]);
    assert.deepEqual(plain(M.edit(c, 'dock', 'style', 'floating')), [{ key: 'dock.theme', value: 'floating' }]);
    assert.deepEqual(plain(M.edit(c, 'dock', 'edge', 'right')), [{ key: 'dock.position', value: 'right' }]);
    assert.deepEqual(plain(M.edit(c, 'dock', 'align', 'start')), []);
    assert.deepEqual(plain(M.edit(c, 'notch', 'style', 'bogus')), []);
    assert.deepEqual(plain(M.edit(c, 'bar', 'style', 'none')), []);
});

test('bar edits on bar.panels change the primary panel; align converts a legacy bar', () => {
    const c = cfg({ bar: { panels: [{ id: 'a', edge: 'top', style: 'classic' }, { id: 'b', edge: 'bottom', style: 'pills' }] } });
    const w = plain(M.edit(c, 'bar', 'edge', 'left'));
    assert.equal(w.length, 1);
    assert.equal(w[0].key, 'bar.panels');
    assert.equal(w[0].value[0].edge, 'left');
    assert.equal(w[0].value[1].edge, 'bottom');
    const off = plain(M.edit(c, 'bar', 'enabled', false))[0].value;
    assert.ok(off.every((p) => p.enabled === false));
    const back = apply(c, M.edit(c, 'bar', 'enabled', false));
    assert.equal(M.fromConfig(back).bar.enabled, false);
    assert.equal(M.fromConfig(apply(back, M.edit(back, 'bar', 'enabled', true))).bar.enabled, true);
    const legacy = cfg();
    const a = plain(M.edit(legacy, 'bar', 'align', 'center'));
    assert.equal(a[0].key, 'bar.panels');
    assert.equal(a[0].value[0].align, 'center');
    assert.equal(M.fromConfig(apply(legacy, a)).bar.align, 'center');
});

test('builder metadata covers every style, align and edge with a translated label', () => {
    const P = loadLibrary(path.join(__dirname, '../modules/settings/layout/PartMeta.js'));
    const en = require('../translations/en.json');
    for (const id of P.ORDER) {
        assert.ok(en[P.part(id).label] && en[P.part(id).desc], id);
        const opts = [].concat(plain(P.styleOptions(id)), plain(P.alignOptions(id)), plain(P.edgeOptions(id)));
        assert.equal(P.styleOptions(id).length, M.stylesOf(id).length);
        for (const o of opts) assert.ok(en[o.label], `${id} ${o.value}: ${o.label}`);
    }
});

test('every edit round-trips through fromConfig', () => {
    for (const part of M.PARTS) {
        for (const e of M.edgesOf(part)) {
            const c = apply(cfg(), M.edit(cfg(), part, 'edge', e));
            assert.equal(M.fromConfig(c)[part].edge, e, `${part} edge ${e}`);
        }
        for (const s of M.stylesOf(part)) {
            const c = apply(cfg(), M.edit(cfg(), part, 'style', s));
            assert.equal(M.fromConfig(c)[part].style, s, `${part} style ${s}`);
        }
        for (const on of [false, true]) {
            const c = apply(cfg(), M.edit(cfg(), part, 'enabled', on));
            assert.equal(M.fromConfig(c)[part].enabled, on, `${part} enabled ${on}`);
        }
    }
});
