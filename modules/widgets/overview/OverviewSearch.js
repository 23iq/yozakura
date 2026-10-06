.pragma library

// Window search of the overview filmstrip (same matching as the grid:
// in-order subsequence on title or class, ranked by score).

function fuzzyMatch(query, target) {
    if (query.length === 0)
        return true;
    if (target.length === 0)
        return false;
    let qi = 0;
    for (let i = 0; i < target.length && qi < query.length; i++) {
        if (target[i] === query[qi])
            qi++;
    }
    return qi === query.length;
}

function fuzzyScore(query, target) {
    if (query.length === 0)
        return 0;
    if (target.length === 0)
        return -1;
    if (target.includes(query))
        return 1000 + (100 - target.length);
    let qi = 0;
    let run = 0;
    let best = 0;
    let score = 0;
    for (let i = 0; i < target.length && qi < query.length; i++) {
        if (target[i] === query[qi]) {
            qi++;
            run++;
            best = Math.max(best, run);
            if (i === 0 || target[i - 1] === " " || target[i - 1] === "-" || target[i - 1] === "_")
                score += 10;
        } else {
            run = 0;
        }
    }
    if (qi !== query.length)
        return -1;
    return score + best * 5;
}

function rank(rawQuery, windows) {
    const query = (rawQuery || "").toLowerCase();
    if (query.length === 0)
        return [];
    return (windows || []).filter(w => {
        if (!w)
            return false;
        return fuzzyMatch(query, (w.title || "").toLowerCase()) || fuzzyMatch(query, (w.class || "").toLowerCase());
    }).map(w => ({
                window: w,
                score: Math.max(fuzzyScore(query, (w.title || "").toLowerCase()), fuzzyScore(query, (w.class || "").toLowerCase()))
            })).sort((a, b) => b.score - a.score).map(x => x.window);
}
