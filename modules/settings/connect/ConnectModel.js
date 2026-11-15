.pragma library

// Pure helpers of the connect pages (Network, Bluetooth, Sound): what a
// row says, which item the details card shows, how a device is drawn.
// Node-tested (tests/settings-connect.test.cjs).

// 0..4 lit bars for a Wi-Fi strength (0..100).
function bars(strength) {
    var s = Number(strength) || 0;
    if (s <= 0)
        return 0;
    if (s > 80)
        return 4;
    if (s > 55)
        return 3;
    if (s > 30)
        return 2;
    return 1;
}

// "5 GHz · Secured" for an access point ({frequency, security}).
function wifiLine(ap, tr) {
    if (!ap)
        return "";
    var parts = [];
    var f = Number(ap.frequency) || 0;
    if (f > 0)
        parts.push(f > 4900 ? "5 GHz" : "2.4 GHz");
    var sec = String(ap.security || "");
    parts.push(sec.length > 0 && sec !== "--" ? tr("prefs.net.secured") : tr("prefs.net.open"));
    return parts.join(" · ");
}

// The item a details card shows: the one picked by `key` (its `field`),
// else the first one that is connected / active (`activeField`), else the
// first one; null for an empty list.
function pick(list, field, key, activeField) {
    var items = list || [];
    var i;
    if (key) {
        for (i = 0; i < items.length; i++) {
            if (items[i] && items[i][field] === key)
                return items[i];
        }
    }
    for (i = 0; i < items.length; i++) {
        if (items[i] && items[i][activeField])
            return items[i];
    }
    return items.length > 0 ? items[0] : null;
}

// A Bluetooth device's glyph (Icons name) from its freedesktop icon name.
function deviceGlyph(icon) {
    var s = String(icon || "");
    if (/headset|headphone/.test(s))
        return "headphones";
    if (/audio|speaker/.test(s))
        return "speaker";
    if (/mouse/.test(s))
        return "mouse";
    if (/keyboard/.test(s))
        return "keyboard";
    if (/phone/.test(s))
        return "phone";
    if (/watch/.test(s))
        return "watch";
    if (/gam|joystick/.test(s))
        return "gamepad";
    if (/computer|laptop/.test(s))
        return "monitor";
    return "bluetooth";
}

// A device's state line: "Connected · 80 %", "Paired", "Not paired".
function deviceLine(d, tr) {
    if (!d)
        return "";
    var parts = [];
    parts.push(d.connecting ? tr("prefs.bt.connecting") : d.connected ? tr("prefs.bt.connected") : d.paired ? tr("prefs.bt.paired") : tr("prefs.bt.new"));
    var b = Number(d.battery);
    if (d.connected && b >= 0)
        parts.push(Math.round(b) + " %");
    return parts.join(" · ");
}

// Volume 0..1.5 -> "75 %".
function percent(v) {
    return Math.round((Number(v) || 0) * 100) + " %";
}
