pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.components
import "KitStates.js" as KitStates
import "DropFit.js" as DropFit
import qs.modules.components.kit

// A choice among many options: a field in the language's control box that
// shows the current option and a caret (underlined in a ghost language);
// a click opens a popup Surface listing the options as ListRows (the
// current one selected). options:
// [{value, text, icon (glyph, optional)}]. `selected(value)` on a pick;
// Enter / Space open it, Up / Down step through the options.
StyledRect {
    id: root

    property var options: []
    property var value
    readonly property int currentIndex: root.options.findIndex(o => o.value === root.value)
    readonly property var current: root.currentIndex >= 0 ? root.options[root.currentIndex] : null
    readonly property bool hovered: mouse.containsMouse || root.activeFocus || popup.opened
    readonly property string look: KitStates.look(false, false, root.hovered && root.enabled)
    readonly property bool boxed: Look.boxedControls

    signal selected(var value)

    function step(d: int) {
        const i = Math.max(0, Math.min(root.options.length - 1, root.currentIndex + d));
        if (i !== root.currentIndex && root.options[i])
            root.selected(root.options[i].value);
    }

    // From the parts' natural widths, never from the Row: the label's width
    // follows ours, so Row.implicitWidth -> implicitWidth -> width -> label
    // width -> Row.implicitWidth was a polish loop that froze the shell.
    implicitWidth: Math.max(Space.px(180), (lead.visible ? lead.implicitWidth + row.spacing : 0) + label.implicitWidth + row.spacing + caret.implicitWidth + Space.m * 2)
    implicitHeight: Space.chip
    variant: KitStates.variant(root.look, "common")
    backgroundOpacity: root.boxed ? 0 : -1
    enableBorder: !root.boxed
    radius: Look.chipRadius(height)
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: true

    Accessible.role: Accessible.ComboBox
    Accessible.name: root.current ? root.current.text : ""

    Keys.onReturnPressed: popup.open()
    Keys.onSpacePressed: popup.open()
    Keys.onUpPressed: root.step(-1)
    Keys.onDownPressed: root.step(1)

    ControlBox {
        shown: root.boxed
        radius: root.radius
        hovered: root.look === "hover"
    }

    // A ghost language (ink: no box at rest) underlines the field.
    Rectangle {
        visible: root.boxed && Look.controlFill(false).a === 0 && Look.controlEdge.a === 0
        anchors.bottom: parent.bottom
        width: parent.width
        height: Space.hairline
        color: popup.opened ? Type.accent : Type.track
    }

    Row {
        id: row
        x: Space.m
        width: root.width - Space.m * 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.s

        Text {
            id: lead
            visible: !!(root.current && root.current.icon)
            anchors.verticalCenter: parent.verticalCenter
            text: root.current && root.current.icon ? root.current.icon : ""
            font.family: Icons.font
            font.pixelSize: Type.iconSize("secondary")
            color: Type.secondary
        }
        KitText {
            id: label
            width: row.width - caret.width - row.spacing - (lead.visible ? lead.width + row.spacing : 0)
            anchors.verticalCenter: parent.verticalCenter
            role: "secondary"
            color: Type.text
            font.weight: Look.labelWeight
            text: root.current ? root.current.text : ""
        }
        Text {
            id: caret
            anchors.verticalCenter: parent.verticalCenter
            text: popup.opened ? Icons.caretUp : Icons.caretDown
            font.family: Icons.font
            font.pixelSize: Type.iconSize("caption")
            color: Type.muted
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            root.forceActiveFocus();
            popup.opened ? popup.close() : popup.open();
        }
    }

    Popup {
        id: popup
        objectName: "dropdownList"
        // Below the control, or above it near the bottom of the window
        y: root.height + Space.xs
        margins: Space.s
        onAboutToShow: {
            let scene = root;
            while (scene.parent)
                scene = scene.parent;
            const top = root.mapToItem(null, 0, 0).y;
            y = DropFit.dropY(top, root.height, height, Space.xs, scene.height);
        }
        width: Math.max(root.width, Space.px(220))
        height: Math.min(list.contentHeight, Space.rowHeight * 7) + Space.xs * 2
        padding: Space.xs
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        onOpened: list.positionViewAtIndex(Math.max(0, root.currentIndex), ListView.Contain)
        background: Surface {
            padding: 0
        }
        contentItem: ListView {
            id: list
            clip: true
            model: root.options
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            delegate: ListRow {
                required property var modelData
                required property int index
                width: ListView.view.width
                title: modelData.text
                selected: index === root.currentIndex
                onClicked: {
                    popup.close();
                    root.selected(modelData.value);
                }
            }
        }
    }
}
