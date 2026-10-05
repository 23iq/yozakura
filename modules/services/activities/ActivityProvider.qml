import QtQuick
import Quickshell
import qs.config
import "ActivityModel.js" as Model

// Base type of every live activity provider. A provider is a singleton
// (`pragma Singleton` + `ActivityProvider { ... }`) listed once in
// ActivityProviders.qml. It publishes plain objects in `activities` (shape
// documented in ActivityModel.js) and handles clicks in `activate()`.
//
// Do expensive work (processes, PipeWire tracking, timers) only while
// `active`: it follows bar.activities.enabled and
// bar.activities.sources[configKey].
Singleton {
    id: provider

    // Provider id, copied into each activity's `source`
    property string source: ""
    // Key under bar.activities.sources that toggles this provider
    property string configKey: source

    readonly property bool active: Model.sourceEnabled(Config.bar ? Config.bar.activities : undefined, configKey)

    // Plain JS objects; reassign the whole list on change
    property var activities: []
    // Downloads/copies/updates (TransferModel.js shape). ActivityService
    // de-duplicates them across providers and shows them as one "downloads"
    // activity (or one per transfer when bar.activities.downloads.aggregate
    // is off).
    property var transfers: []
    // True for providers fed by the backend "transfers" service
    property bool backendSource: false

    // Click on one of this provider's islands. `button` is a Qt.MouseButton,
    // `screenName` the screen the island lives on.
    function activate(activity, button, screenName) {
    }

    // Action on one of this provider's transfers: "cancel", "suspend",
    // "resume" (see transfer.actions). "open" is handled by ActivityService.
    function transferAction(transfer, action) {
    }
}
