import QtQuick
import qs.modules.components.kit

// Title row of a notch panel: the section label (kit label role), an
// optional summary (caption, tabular figures) and trailing IconButtons
// (children, size "s").
Item {
    id: title

    property string text: ""
    property string summary: ""

    default property alias actions: actionsRow.data

    implicitHeight: Math.max(titleText.implicitHeight, actionsRow.implicitHeight)

    KitText {
        id: titleText
        anchors.left: parent.left
        anchors.right: summaryText.left
        anchors.rightMargin: Space.s
        anchors.verticalCenter: parent.verticalCenter
        role: "label"
        text: title.text
    }
    KitText {
        id: summaryText
        anchors.right: actionsRow.left
        anchors.rightMargin: actionsRow.implicitWidth > 0 ? Space.s : 0
        anchors.verticalCenter: parent.verticalCenter
        role: "caption"
        tabular: true
        text: title.summary
    }
    Row {
        id: actionsRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.xs
    }
}
