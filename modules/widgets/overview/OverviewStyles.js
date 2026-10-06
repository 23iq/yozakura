.pragma library

// Overview style registry. `overview.style` picks how the workspaces are laid
// out; the scrolling compositor layout always keeps its own tape view.
// OverviewView maps each id to a component, so adding a style = one entry here
// + one component + a translation.

var styles = [
    { id: "grid", labelKey: "settings.shell.overview_style_grid" },
    { id: "strip", labelKey: "settings.shell.overview_style_strip" }
];

function ids() {
    return styles.map(s => s.id);
}

function labelKey(id) {
    const s = styles.find(x => x.id === id);
    return s ? s.labelKey : styles[0].labelKey;
}

function resolve(style, compositorLayout) {
    if (compositorLayout === "scrolling")
        return "scrolling";
    return ids().indexOf(style) >= 0 ? style : "grid";
}
