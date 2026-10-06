pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.settings.controls
import qs.modules.settings.store
import "PartMeta.js" as PartMeta

// Layout page: the composable layout. A live screen where the bar, notch
// and dock are dragged to any edge (or onto the shelf to hide them), and
// the selected part's switch, style, edge and alignment. Every change goes
// through LayoutModel.edit (ShellLayout.edit), which writes only the
// existing keys, so the shell and the preview follow at once.
Item {
    id: root

    property var entry
    property string selectedPart: "bar"

    objectName: "layoutBuilder"
    implicitWidth: 560
    implicitHeight: col.implicitHeight

    // Applies one part change; each write sees the previous one
    function apply(part: string, field: string, value: var) {
        const writes = ShellLayout.edit(part, field, value);
        for (const w of writes)
            SettingsStore.set(w.key, w.value);
        root.selectedPart = part;
    }

    Column {
        id: col
        width: parent.width
        spacing: Metrics.spacing * 4

        ScreenMock {
            id: mock
            objectName: "layoutBuilderMock"
            width: parent.width
            selectedPart: root.selectedPart
            onSelect: part => root.selectedPart = part
            onEdit: (part, field, value) => root.apply(part, field, value)
        }

        SelectorControl {
            objectName: "layoutBuilderParts"
            width: parent.width
            translate: true
            options: PartMeta.ORDER.map(p => ({
                        "value": p,
                        "label": PartMeta.part(p).label,
                        "icon": PartMeta.part(p).icon
                    }))
            value: root.selectedPart
            onSelected: value => root.selectedPart = value
        }

        PartInspector {
            width: parent.width
            part: root.selectedPart
            onEdit: (part, field, value) => root.apply(part, field, value)
        }
    }
}
