const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const V = loadLibrary(path.join(__dirname, '../modules/services/UpdateVersions.js'));
// The cases the backend (Go) and install.sh share with this helper.
const F = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/update-channels.json'), 'utf8'));

test('parse follows the shared fixture', () => {
    for (const c of F.parse) {
        const v = V.parse(c.tag);
        if (c.version === null) {
            assert.equal(v, null, `${c.tag} is not a version`);
            continue;
        }
        assert.ok(v, `${c.tag} parses`);
        assert.equal(V.format(v), c.version, c.tag);
        assert.equal(v.beta >= 0, c.beta, c.tag);
    }
});

test('compare follows the shared fixture, both ways', () => {
    for (const [a, b, want] of F.compare) {
        assert.equal(V.compare(a, b), want, `${a} vs ${b}`);
        assert.equal(V.compare(b, a), 0 - want || 0, `${b} vs ${a}`);
    }
    assert.equal(V.isNewer('0.3.2', '0.3.2-beta.9'), true);
    assert.equal(V.isNewer('nightly', '0.1.2'), false);
    assert.equal(V.isNewer('0.3.2', 'garbage'), false);
});

test('select follows the shared fixture, whatever the tag order and shape', () => {
    for (const c of F.select) {
        assert.equal(V.select(c.tags, c.channel), c.want, `${c.channel} ${c.tags}`);
        assert.equal(V.select([...c.tags].reverse(), c.channel), c.want, `${c.channel} reversed`);
        // GitHub's tags API returns objects
        assert.equal(V.select(c.tags.map(name => ({ name })), c.channel), c.want, `${c.channel} objects`);
    }
    assert.equal(V.select(null, 'stable'), '');
});

test('channel falls back to stable', () => {
    assert.equal(V.channel('beta'), 'beta');
    assert.equal(V.channel('git'), 'git');
    assert.equal(V.channel(''), 'stable');
    assert.equal(V.channel(undefined), 'stable');
    assert.equal(V.channel('nightly'), 'stable');
});

test('describe reads git describe --long --always output', () => {
    const sha = 'a'.repeat(40);
    assert.deepEqual({ ...V.describe(`0.3.1-5-g${sha}`) }, { tag: '0.3.1', distance: 5, commit: sha });
    assert.deepEqual({ ...V.describe(`0.3.2-beta.1-0-g${sha}\n`) }, { tag: '0.3.2-beta.1', distance: 0, commit: sha });
    assert.deepEqual({ ...V.describe(sha) }, { tag: '', distance: -1, commit: sha });
    assert.deepEqual({ ...V.describe('') }, { tag: '', distance: -1, commit: '' });
    assert.deepEqual({ ...V.describe('fatal: not a git repository') }, { tag: '', distance: -1, commit: '' });
});

test('installed is the version file or a newer tag the checkout contains', () => {
    assert.equal(V.installed('0.3.1', V.describe('0.3.1-12-gabcdef0')), '0.3.1');
    assert.equal(V.installed('0.3.1', V.describe('0.3.2-beta.1-0-gabcdef0')), '0.3.2-beta.1');
    assert.equal(V.installed('0.3.2', V.describe('v0.2.0-40-gabcdef0')), '0.3.2');
    assert.equal(V.installed('0.3.1', V.describe('')), '0.3.1');
    assert.equal(V.installed('', V.describe('0.3.1-0-gabcdef0')), '0.3.1');
    assert.equal(V.installed('0.3.1', null), '0.3.1');
});

test('tagUpdate: only a newer target of the channel is an update', () => {
    const tags = [{ name: 'v0.3.0' }, { name: '0.4.1' }, { name: '0.4.2-beta.1' }];
    assert.equal(V.tagUpdate(tags, 'stable', '0.4.1'), '');
    assert.equal(V.tagUpdate(tags, 'beta', '0.4.1'), '0.4.2-beta.1');
    assert.equal(V.tagUpdate(tags, 'stable', '0.4.0'), '0.4.1');
    // a beta install on stable is never pushed back to the older release
    assert.equal(V.tagUpdate(tags, 'stable', '0.4.2-beta.1'), '');
    assert.equal(V.tagUpdate(tags, 'beta', '0.4.2-beta.1'), '');
    assert.equal(V.tagUpdate([...tags, { name: '0.4.2' }], 'beta', '0.4.2-beta.1'), '0.4.2');
    assert.equal(V.tagUpdate(tags, 'git', '0.0.1'), '');
});

test('gitCompare / gitLabel', () => {
    const tip = '0123456789abcdef0123456789abcdef01234567';
    assert.equal(V.gitCompare(tip, tip), 'same');
    assert.equal(V.gitCompare(tip + '\n', '0123456789'), 'same');
    assert.equal(V.gitCompare(tip, 'fedcba9876543210fedcba9876543210fedcba98'), 'check');
    assert.equal(V.gitCompare(tip, ''), 'unknown');
    assert.equal(V.gitCompare('{"message":"Not Found"}', tip), 'unknown');
    assert.equal(V.gitLabel(tip), 'main @ 0123456');
});

test('the version floor follows the shared fixture', () => {
    assert.equal(V.LAST_WITHOUT_CHANNELS, F.lastReleaseWithoutChannels);
    for (const c of F.hasChannels)
        assert.equal(V.hasChannels(V.parse(c.tag)), c.want, c.tag);
    assert.equal(V.hasChannels(null), false);
});

test('tagUpdate: no notice while every release predates update channels', () => {
    const today = ['0.1.1', 'v0.1.2', '0.2.0', '0.3.0', '0.3.1'].map(name => ({ name }));
    for (const ch of ['stable', 'beta']) {
        assert.equal(V.tagUpdate(today, ch, '0.2.0'), '', `${ch} from 0.2.0`);
        assert.equal(V.tagUpdate(today, ch, ''), '', `${ch} without a version`);
    }
    assert.equal(V.tagUpdate([...today, { name: '0.3.2-beta.1' }], 'beta', '0.3.1'), '0.3.2-beta.1');
});

test('gitFollowsMain: the git notice is for checkouts that follow main', () => {
    assert.equal(V.gitFollowsMain('main\n'), true);
    assert.equal(V.gitFollowsMain('HEAD'), true, 'detached: an update returns to main');
    assert.equal(V.gitFollowsMain(''), true);
    assert.equal(V.gitFollowsMain('dev'), false);
    assert.equal(V.gitFollowsMain('feature/x'), false);
});
