.pragma library

// Layout sizes per density. "cozy" equals the historic literal sizes; the
// other two scale every key (compact x0.86, roomy x1.14).
var COZY = {
    rowHeight: 48, iconSize: 32, badgeHeight: 22, spacing: 8, padding: 16,
    launcherCompactW: 464, launcherCompactH: 296, launcherWideW: 900, launcherWideH: 392,
    launcherLeftPanelW: 300, dashTabWidth: 48, dashWideW: 600, dashNarrowW: 400, dashH: 430,
    menuW: 160, menuItemH: 32, osdW: 220, osdMargin: 100, toastW: 360, bentoCell: 132, sheetW: 420
};

var FACTORS = { compact: 0.86, cozy: 1, roomy: 1.14 };

function metrics(density) {
    var f = FACTORS[density] !== undefined ? FACTORS[density] : 1;
    var out = {};
    for (var k in COZY)
        out[k] = Math.round(COZY[k] * f);
    return out;
}
