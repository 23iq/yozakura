pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.settings.store
import qs.modules.bar.workspaces.branch
import "../../bar/workspaces/branch/BranchGeometry.js" as BranchGeometry

// Blossom shape of the branch indicator (workspaces.branchBlossom): one chip
// per shape, each a 3-slot branch drawn in that shape and the chosen role.
PreviewChips {
    id: root

    property var entry

    key: "workspaces.branchBlossom"
    ids: BranchGeometry.SHAPES
    current: BranchGeometry.shape(SettingsStore.get("workspaces.branchBlossom"))
    labelPrefix: "prefs.branch."
    namePrefix: "blossomChip:"

    preview: BranchStrip {
        property string chipId
        slot: root.slot
        shape: chipId
        role: SettingsStore.get("workspaces.branchColor") || "primary"
        petalFall: false
        slots: [
            {
                "id": 1,
                "windows": 3,
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
}
