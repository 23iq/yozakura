import QtQuick
import qs.modules.components.kit

// An inline text editor in a kit type role (ListRow.titleEditor: rename,
// alias): no box, the row's own font and ink, accent selection. Takes focus
// and selects its text when shown (`autoFocus`).
TextInput {
    id: root

    property string role: "body"
    property bool autoFocus: true

    font.family: Type.family(root.role)
    font.pixelSize: Type.size(root.role)
    font.weight: Look.labelWeight
    color: Type.text
    selectionColor: Qt.rgba(Type.accent.r, Type.accent.g, Type.accent.b, 0.3)
    selectedTextColor: Type.text
    selectByMouse: true
    clip: true
    verticalAlignment: TextInput.AlignVCenter

    Component.onCompleted: {
        if (root.autoFocus)
            Qt.callLater(() => {
                root.forceActiveFocus();
                root.selectAll();
            });
    }
}
