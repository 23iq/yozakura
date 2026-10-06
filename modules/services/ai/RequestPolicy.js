.pragma library

// Timeout and retry rules of HTTP chat requests (pure, node-tested).
// Settings: ai.providers.timeout (seconds, 0 = none) and
// ai.providers.retries (extra attempts).

var MAX_RETRIES = 5;

// curl arguments for the request timeout.
function timeoutArgs(seconds) {
    var s = Math.round(Number(seconds) || 0);
    return s > 0 ? ["--max-time", String(s)] : [];
}

function retries(n) {
    return Math.max(0, Math.min(MAX_RETRIES, Math.round(Number(n) || 0)));
}

// Whether a failed attempt may be repeated: never once something was
// streamed (the user already saw part of the answer) or after a stop, only
// for transient failures (curl connection errors, timeouts, rate limits,
// overloaded or 5xx servers).
function shouldRetry(r) {
    var o = r || {};
    if (o.aborted || o.streamed || !o.error)
        return false;
    if (o.attempt >= retries(o.max))
        return false;
    if ([6, 7, 28, 35, 52, 55, 56].indexOf(o.curlCode) >= 0)
        return true;
    return /\b(429|5\d\d)\b|rate.?limit|overloaded|timed? ?out|temporarily|unavailable/i.test(String(o.error));
}

// Delay before attempt `attempt` (1-based retry number), in ms.
function backoff(attempt) {
    return Math.min(8000, 800 * Math.pow(2, Math.max(0, attempt - 1)));
}
