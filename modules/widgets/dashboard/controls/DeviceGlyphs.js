.pragma library

// Icon names (keys of Icons) for the device panels
// (tests/device-glyphs.test.cjs).

// Wi-Fi signal strength (0..100) -> wifi glyph.
function wifiGlyph(strength) {
    var s = Number(strength) || 0;
    if (s > 80)
        return "wifiHigh";
    if (s > 55)
        return "wifiMedium";
    return s > 30 ? "wifiLow" : "wifiNone";
}

// BlueZ device icon name ("audio-headset", "input-mouse", ...) -> glyph.
function bluetoothGlyph(icon) {
    var i = String(icon || "");
    var rules = [
        [["audio-headset", "headphone"], "headphones"],
        [["input-keyboard"], "keyboard"],
        [["input-mouse"], "mouse"],
        [["phone"], "phone"],
        [["watch"], "watch"],
        [["input-gaming", "gamepad"], "gamepad"],
        [["printer"], "printer"],
        [["camera"], "camera"],
        [["audio-speakers", "speaker"], "speaker"]
    ];
    for (var r = 0; r < rules.length; r++) {
        for (var k = 0; k < rules[r][0].length; k++) {
            if (i.indexOf(rules[r][0][k]) !== -1)
                return rules[r][1];
        }
    }
    return "bluetooth";
}

// Bluetooth row subtitle parts: state, then the battery when known.
function bluetoothStatus(connected, paired, battery, labels) {
    var parts = [connected ? labels.connected : (paired ? labels.paired : labels.notPaired)];
    if (battery !== undefined && battery !== null && battery >= 0)
        parts.push(Math.round(battery) + "%");
    return parts.join(" · ");
}
