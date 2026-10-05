import QtQuick

// Base of a launcher result provider (registry: ../Providers.js). A
// provider turns a query into `results` (synchronously or later, e.g. after
// a process) and runs a result. Result fields:
//   key       unique within the provider
//   title     main line; subtitle: second line (optional)
//   icon      Icons glyph (text) shown when there is no image
//   image     icon theme name (apps) or file URL (thumbnails)
//   badge     short tag on the right (provider name, unit...)
//   hint      what Enter does ("Copy", "Run"); shown on the selected row
//   emphasis  true for an answer row (calculator): bigger title
//   inert     true for an info row (nothing to run)
//   data      provider payload
QtObject {
    id: provider

    property string providerId: ""
    // LauncherResults: close(), setSearch(text), prefixFor(id)
    property var host: null
    property string query: ""
    property string mode: ""        // "prefix" | "mixed" | "empty"
    property var results: []
    property bool busy: false
    // Rows kept in mixed searches (0 = all).
    property int mixedLimit: 3

    function search(text, searchMode) {
        provider.query = text;
        provider.mode = searchMode;
        provider.results = provider.compute(text, searchMode);
    }

    // Synchronous providers override this.
    function compute(text, searchMode) {
        return [];
    }

    function clear() {
        provider.query = "";
        provider.mode = "";
        if (provider.results.length > 0)
            provider.results = [];
    }

    // Runs `item` (option: an id from options(), "" = default action).
    // Returns true when the launcher should close.
    function activate(item, option) {
        return false;
    }

    // Secondary actions for Shift+Enter / right click: [{id, text, icon}].
    function options(item) {
        return [];
    }

    // Text Tab completes the search to (e.g. "> preset "), "" = none.
    function completion(item) {
        return "";
    }
}
