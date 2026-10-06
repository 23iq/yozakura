.pragma library

// Monitor layout saved per machine: [{id, name, enabled, width, height,
// refresh, x, y, autoPosition, scale, transform, vrr}] (item shape:
// config/meta/displays.js; logic: modules/services/DisplayModel.js). Applied
// live by DisplaysService and rendered into the compositor config by the
// backend. Machine specific: presets never carry it.
var data = {
    "monitors": []
}
