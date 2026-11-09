.pragma library

// Let go of the keyboard before a layer surface drops keyboard focus:
// commit pending input-method (preedit) text, then take focus off the item
// holding it, so no text-input-v3 object outlives the focus change.
function release(inputMethod, focused) {
    if (inputMethod && typeof inputMethod.commit === "function")
        inputMethod.commit();
    if (focused)
        focused.focus = false;
}
