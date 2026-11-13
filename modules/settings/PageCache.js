.pragma library

// The pages SettingsPageHost keeps alive: [{id, item}], most recently
// visited first, at most `keep`. Pure (tests/settings-page-cache.test.cjs).

function find(pages, id) {
    for (var i = 0; i < pages.length; i++) {
        if (pages[i].id === id)
            return pages[i].item;
    }
    return null;
}

// A visit of `id` (shown with `item`): it moves to the front; past `keep`
// the least recently visited pages are dropped. Returns {pages, dropped:
// [item...]} (the caller destroys the dropped items).
function visit(pages, id, item, keep) {
    var rest = pages.filter(function (p) {
        return p.id !== id;
    });
    var out = [{
            "id": id,
            "item": item
        }].concat(rest);
    var limit = Math.max(1, keep || 1);
    return {
        "pages": out.slice(0, limit),
        "dropped": out.slice(limit).map(function (p) {
            return p.item;
        })
    };
}
