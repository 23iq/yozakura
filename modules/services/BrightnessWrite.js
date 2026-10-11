.pragma library

// Single-flight, latest-wins brightness writer (pure logic, see Brightness.qml).
//
// A DDC/CI write takes 150-350 ms and ddcutil serialises concurrent calls on
// the bus lock, so firing one process per tick builds a backlog the monitor
// then replays value by value (late and out of order). Instead at most one
// write is in flight per monitor; while it runs only the newest requested
// value is kept, and it is written as soon as the bus is free.

function create() {
    // fast: use the cheap ddcutil flags until a write with them fails.
    return {
        inFlight: false,
        pending: null,
        current: null,
        fast: true
    };
}

function take(st) {
    if (st.inFlight || st.pending === null)
        return null;
    st.current = st.pending;
    st.pending = null;
    st.inFlight = true;
    return st.current;
}

// Record the newest wanted raw value. Returns the raw value to write right
// now, or null when a write is already running (it is picked up by done()).
function submit(st, raw) {
    st.pending = raw;
    return take(st);
}

// The running write finished. Returns the next raw value to write or null.
// A failed fast write is retried once with the plain flags (older ddcutil may
// not know them) unless a newer value is already waiting.
function done(st, ok) {
    st.inFlight = false;
    if (!ok && st.fast) {
        st.fast = false;
        if (st.pending === null)
            st.pending = st.current;
    }
    return take(st);
}

function command(isDdc, bus, raw, fast) {
    if (!isDdc)
        return ["brightnessctl", "--class", "backlight", "s", String(raw), "--quiet"];
    // --skip-ddc-checks drops the per-process display probe, --noverify the
    // read-back: 320 ms -> 145 ms per write on a Lenovo Legion 27Q-10.
    const flags = fast ? ["--skip-ddc-checks", "--noverify"] : [];
    return ["ddcutil", "-b", String(bus)].concat(flags, ["setvcp", "10", String(raw)]);
}
