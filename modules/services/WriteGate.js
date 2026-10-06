.pragma library

// Holds compositor config writes back while a display change is waiting for
// confirmation (tests/display-model.test.cjs): rendering the saved layout
// then would undo the change being tested.
function create() {
    return {
        "deferred": false
    };
}

// True when the write may go ahead; otherwise it is remembered.
function request(gate, pending) {
    if (pending) {
        gate.deferred = true;
        return false;
    }
    return true;
}

// True once, when the session left pending and a write was held back.
function release(gate, pending) {
    if (pending || !gate.deferred)
        return false;
    gate.deferred = false;
    return true;
}
