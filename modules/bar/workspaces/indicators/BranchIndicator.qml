import QtQuick
import qs.modules.bar.workspaces.branch

// Settings preview of the "branch" style (a strip style, see
// IndicatorStyles.js): three workspaces, a blossom with two windows, the
// open active one and a bud.
BranchStrip {
    property var indicator: null

    slot: indicator ? indicator.slotSize : 0
    width: slot * 3
    height: slot
    petalFall: false
    slots: [
        {
            "id": 1,
            "windows": 2,
            "urgent": false,
            "active": false
        },
        {
            "id": 2,
            "windows": 1,
            "urgent": false,
            "active": true
        },
        {
            "id": 3,
            "windows": 0,
            "urgent": false,
            "active": false
        }
    ]
}
