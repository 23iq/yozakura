.pragma library

// When a config domain's coalesced auto-save writes (ConfigFile.qml,
// tests/write-throttle.test.cjs). Edits restart a short timer (`delay`), so
// a burst becomes one write once it stops; while the burst goes on (a
// slider dragged for seconds) a write still happens every `maxWait` ms, so
// another process that follows the file (the main shell under a separate
// Settings window) sees the change live, a few times per second at most.
//
// now: ms; since: when the oldest unwritten edit was made (-1: none);
// delay / maxWait: ms (maxWait <= 0: no cap).
// Returns "now" (write at once) or "later" (restart the timer).
function decide(now, since, delay, maxWait) {
    if (delay <= 0)
        return "now";
    if (since >= 0 && maxWait > 0 && now - since >= maxWait)
        return "now";
    return "later";
}
