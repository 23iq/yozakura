.pragma library

// Exponential backoff for retried requests (WeatherService).
// attempt   1 for the first retry, 2 for the second, ...
// base      delay of the first retry (ms)
// cap       the longest delay (ms)
// jitter    0..1: the delay is spread by up to +-jitter of itself so many
//           shells do not retry in lockstep (0 = exact)
// rand      a 0..1 random source (Math.random; tests pass a fixed one)
function delay(attempt, base, cap, jitter, rand) {
    const n = Math.max(1, Math.floor(Number(attempt) || 1));
    const b = Math.max(0, Number(base) || 0);
    const c = Math.max(b, Number(cap) || 0);
    // 2^30 already exceeds any sane cap; avoid Infinity for huge attempts
    const raw = Math.min(c, b * Math.pow(2, Math.min(n - 1, 30)));
    const j = Math.min(1, Math.max(0, Number(jitter) || 0));
    if (j === 0)
        return Math.round(raw);
    const r = typeof rand === "function" ? rand() : Math.random();
    const spread = raw * j * (2 * r - 1);
    return Math.round(Math.min(c, Math.max(b, raw + spread)));
}
