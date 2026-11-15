.pragma library

// Pure geometry and data of the home tile scenes (home/*Scene.qml), so the
// scenes stay drawing only. Node-tested (tests/settings-home.test.cjs).

// A compositor length (px on a real screen) in a scene `height` px tall: a
// screen of ~360 logical px of height maps onto it, so a gap of 8 stays
// visible while 0 stays 0; never under one pixel when it is set.
function scaled(px, height) {
    var v = Number(px) || 0;
    if (v <= 0)
        return 0;
    return Math.max(1, Math.round(v * height / 360));
}

// The windows of the Windows tile, as the layout tiles three (four in
// master) of them in a w x h screen: [{x, y, w, h, active}]. `outer` is the
// gap to the screen edge, `inner` the one between windows. Scrolling lays
// out columns that run past the right edge (the scene clips them).
function windows(layout, w, h, inner, outer) {
    var x0 = outer, y0 = outer, W = Math.max(0, w - outer * 2), H = Math.max(0, h - outer * 2);
    function r(x, y, ww, hh, active) {
        return {
            "x": Math.round(x),
            "y": Math.round(y),
            "w": Math.max(0, Math.round(ww)),
            "h": Math.max(0, Math.round(hh)),
            "active": active === true
        };
    }
    if (layout === "scrolling") {
        var cw = W * 0.46;
        return [r(x0, y0, cw, H, false), r(x0 + cw + inner, y0, cw, H, true), r(x0 + (cw + inner) * 2, y0, cw, H, false)];
    }
    if (layout === "master") {
        var mw = (W - inner) * 0.6, sw = W - inner - mw, sh = (H - inner * 2) / 3;
        var out = [r(x0, y0, mw, H, true)];
        for (var i = 0; i < 3; i++)
            out.push(r(x0 + mw + inner, y0 + i * (sh + inner), sw, sh, false));
        return out;
    }
    // dwindle: halves, the second one split again
    var hw = (W - inner) / 2, hh2 = (H - inner) / 2;
    return [r(x0, y0, hw, H, true), r(x0 + hw + inner, y0, hw, hh2, false), r(x0 + hw + inner, y0 + hh2 + inner, hw, hh2, false)];
}

// The letters on the first keys of two rows of a layout (xkb code): what
// the Keyboard tile's keycaps read ("us" Q W E R T / A S D F G, "de"
// QWERTZ, "fr" AZERTY, "ru" Й Ц У К Е / Ф Ы В А П).
var ROWS = {
    "qwerty": ["QWERTY", "ASDFGH"],
    "qwertz": ["QWERTZ", "ASDFGH"],
    "azerty": ["AZERTY", "QSDFGH"],
    "cyrillic": ["ЙЦУКЕН", "ФЫВАПР"],
    "greek": [";ςΕΡΤΥ", "ΑΣΔΦΓΗ"],
    "hebrew": ["/'קראט", "שדגכעי"],
    "arabic": ["ضصثقفغ", "شسيبلا"],
    "dvorak": ["',.PYF", "AOEUID"],
    "colemak": ["QWFPGJ", "ARSTDH"]
};
var FAMILY = {
    "de": "qwertz",
    "at": "qwertz",
    "ch": "qwertz",
    "cz": "qwertz",
    "sk": "qwertz",
    "hu": "qwertz",
    "si": "qwertz",
    "hr": "qwertz",
    "rs": "qwertz",
    "pl": "qwerty",
    "fr": "azerty",
    "be": "azerty",
    "ru": "cyrillic",
    "ua": "cyrillic",
    "by": "cyrillic",
    "bg": "cyrillic",
    "kz": "cyrillic",
    "mk": "cyrillic",
    "gr": "greek",
    "il": "hebrew",
    "ara": "arabic",
    "eg": "arabic",
    "sa": "arabic",
    "ir": "arabic"
};

// [[top row letters], [home row letters]] for a layout entry ({layout,
// variant}) or a bare code; QWERTY when unknown.
function keyRows(entry, count) {
    var code = String(entry && typeof entry === "object" ? entry.layout || "" : entry || "").toLowerCase();
    var variant = String(entry && typeof entry === "object" ? entry.variant || "" : "").toLowerCase();
    var fam = variant.indexOf("dvorak") >= 0 ? "dvorak" : variant.indexOf("colemak") >= 0 ? "colemak" : FAMILY[code] || "qwerty";
    var n = Math.max(1, Math.min(6, count || 5));
    return ROWS[fam].map(function (row) {
        return Array.from(row).slice(0, n);
    });
}

// What the Devices tile gauges show, in order, from what the system has:
// [{id, icon, value (0..1, -1 none), text}]. ctx = {battery: {available,
// percent, charging}, volume (0..1.5, -1 none), muted, network: {name,
// strength (0..100), ethernet}, bluetooth: {enabled, connected (count)}}.
function gauges(ctx, icons) {
    var out = [];
    var b = ctx.battery || {};
    if (b.available)
        out.push({
            "id": "battery",
            "icon": b.charging ? icons.batteryCharging : b.percent > 60 ? icons.batteryHigh : b.percent > 25 ? icons.batteryMedium : icons.batteryLow,
            "value": Math.max(0, Math.min(1, b.percent / 100)),
            "text": Math.round(b.percent) + "%"
        });
    var net = ctx.network || {};
    if (net.ethernet && !net.name)
        out.push({
            "id": "network",
            "icon": icons.ethernet,
            "value": 1,
            "text": ""
        });
    else
        out.push({
            "id": "network",
            "icon": !net.name ? icons.wifiSlash : net.strength > 66 ? icons.wifiHigh : net.strength > 33 ? icons.wifiMedium : icons.wifiLow,
            "value": net.name ? Math.max(0, Math.min(1, (net.strength || 0) / 100)) : 0,
            "text": net.name ? Math.round(net.strength || 0) + "%" : ""
        });
    if (typeof ctx.volume === "number" && ctx.volume >= 0)
        out.push({
            "id": "volume",
            "icon": ctx.muted ? icons.speakerSlash : ctx.volume <= 0 ? icons.speakerNone : ctx.volume < 0.4 ? icons.speakerLow : icons.speakerHigh,
            "value": ctx.muted ? 0 : Math.max(0, Math.min(1, ctx.volume)),
            "text": Math.round(ctx.volume * 100) + "%"
        });
    var bt = ctx.bluetooth || {};
    out.push({
        "id": "bluetooth",
        "icon": !bt.enabled ? icons.bluetoothOff : bt.connected > 0 ? icons.bluetoothConnected : icons.bluetooth,
        "value": bt.enabled ? (bt.connected > 0 ? 1 : 0.15) : 0,
        "text": bt.enabled && bt.connected > 0 ? String(bt.connected) : ""
    });
    return out;
}
