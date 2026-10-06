import QtQuick
import QtQuick.Layouts
import qs.modules.aicenter.common

// Empty-state column: centred in the view, scrolling instead of spilling
// over the header and the composer when the bar is short. Children are laid
// out by a ColumnLayout (Layout.* attached properties work).
Flickable {
    id: root
    default property alias content: column.data
    property int maxContentWidth: 560
    property alias spacing: column.spacing

    clip: true
    contentWidth: width
    contentHeight: Math.max(height, column.implicitHeight + 2 * BarLook.pad)
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    ColumnLayout {
        id: column
        width: Math.max(0, Math.min(root.width - 2 * BarLook.pad, root.maxContentWidth))
        x: (root.width - width) / 2
        y: Math.max(BarLook.pad, (root.height - implicitHeight) / 2)
    }
}
