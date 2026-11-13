.pragma library

// Whether a control under the pointer may take a wheel event (sliders,
// level sliders, knobs). On a page that scrolls, the wheel belongs to the
// page: a control takes it only once it holds the keyboard focus (clicked or
// reached with Tab), so scrolling past a slider never moves it. Outside a
// scrolling view (a bar popup, a panel) the wheel adjusts it as before.
// Pure but for the item tree it walks; tests/kit-wheel.test.py.

// The nearest ancestor that scrolls now (a Flickable / ListView with more
// content than room, interactive).
function scrollingAncestor(item) {
    for (var p = item ? item.parent : null; p; p = p.parent) {
        if (p.contentHeight !== undefined && p.contentWidth !== undefined && p.interactive !== false && p.flickableDirection !== undefined) {
            if (p.contentHeight > p.height + 1 || p.contentWidth > p.width + 1)
                return p;
        }
    }
    return null;
}

// The control (or the focusable control that wraps it, up to the scrolling
// view) holds the keyboard focus.
function focused(item, stop) {
    for (var p = item; p && p !== stop; p = p.parent) {
        if (p.activeFocus === true && (p === item || p.activeFocusOnTab === true))
            return true;
    }
    return false;
}

function owns(item) {
    var view = scrollingAncestor(item);
    return view === null || focused(item, view);
}
