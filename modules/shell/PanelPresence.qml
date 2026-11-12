import QtQuick
import qs.modules.components
import "PanelPresence.js" as Presence

// Whether the unified panel window of a screen is mapped
// (performance.hidePanelInFullscreen): always while the flag is off;
// otherwise it maps at once whenever PanelPresence.js finds a reason, and
// unmaps only once "no reason" has held for `settleInterval` ms, so
// entering fullscreen unmaps once (after the bar, notch and dock slid out)
// and a quick toggle unmaps nothing.
QtObject {
    id: root

    property bool enabled: false
    // PanelPresence.js state
    property var state: ({})
    property int settleInterval: 400

    readonly property var reasons: Presence.reasons(root.state)
    readonly property bool wanted: !root.enabled || root.reasons.length > 0
    readonly property bool mapped: root.wanted || root._hold.output === true || !root._hold.settled

    property SettleGate _hold: SettleGate {
        value: root.wanted
        interval: root.settleInterval
    }
}
