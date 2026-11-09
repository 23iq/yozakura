pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
import "SearchKeys.js" as SearchKeys

// The search field of the shell (launcher and its tabs, pickers, galleries).
// Default: no box, the query large and light (title size, regular weight)
// with a calm fading caret, a muted leading glyph (`glyph`: the search
// glyph, or the active mode's `prefixIcon`) and trailing key hints (`hints:
// ["cc", "="]`, shown while the field is empty); `rule: true` draws the
// Divider under it. `boxed: true` is the compact toolbar field: body-size
// text on the language's raised box (Look.raisedFill), control height.
// `leading` / `trailing` replace the glyph / hints.
//
// Keyboard (SearchKeys.js): Enter -> accepted (Shift: shiftAccepted),
// Escape -> escapePressed (and clears with `clearOnEscape`), arrows / Page /
// Home / End -> the matching *Pressed signal (Left / Right only at the text
// edges unless `disableCursorNavigation`), Tab / Shift+Tab with
// `handleTabNavigation`, Backspace on empty, Ctrl+R / P / Up / Down.
Item {
    id: root

    property alias text: textField.text
    property alias placeholderText: textField.placeholderText
    property string prefixIcon: ""
    property string glyph: root.prefixIcon !== "" ? root.prefixIcon : Icons.magnifyingGlass
    property var hints: []
    property bool rule: false
    property bool boxed: false
    property bool clearOnEscape: true
    property bool handleTabNavigation: false
    property bool passwordMode: false
    property bool disableCursorNavigation: false
    property Component leading: glyphComponent
    property Component trailing: hintsComponent
    readonly property alias field: textField
    readonly property bool hovered: hover.hovered

    signal searchTextChanged(string text)
    signal accepted
    signal shiftAccepted
    signal backspaceOnEmpty
    signal tabPressed
    signal shiftTabPressed
    signal ctrlRPressed
    signal ctrlPPressed
    signal ctrlUpPressed
    signal ctrlDownPressed
    signal escapePressed
    signal downPressed
    signal upPressed
    signal leftPressed
    signal rightPressed
    signal pageDownPressed
    signal pageUpPressed
    signal homePressed
    signal endPressed

    function focusInput() {
        textField.forceActiveFocus();
    }

    function clear() {
        textField.text = "";
    }

    implicitWidth: row.implicitWidth + (root.boxed ? Space.m * 2 : 0)
    implicitHeight: root.boxed ? Space.controlM : Space.rowHeight

    HoverHandler {
        id: hover
    }

    // The toolbar box (boxed): the language's raised fill, chip radius.
    Rectangle {
        objectName: "searchBox"
        anchors.fill: parent
        visible: root.boxed
        radius: Look.chipRadius(height)
        color: Look.raisedFill(root.hovered || textField.activeFocus)
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: root.boxed ? Space.m : 0
        anchors.rightMargin: root.boxed ? Space.m : 0
        spacing: Space.s

        Loader {
            active: root.leading !== null
            visible: active
            sourceComponent: root.leading
            Layout.alignment: Qt.AlignVCenter
        }

        TextField {
            id: textField
            objectName: "searchText"
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            background: null
            leftPadding: 0
            rightPadding: 0
            font.family: Type.family(root.boxed ? "body" : "title")
            font.pixelSize: Type.size(root.boxed ? "body" : "title")
            font.weight: Font.Normal
            color: Type.text
            placeholderTextColor: Type.muted
            selectionColor: Qt.alpha(Type.accent, 0.3)
            selectedTextColor: Type.text
            cursorDelegate: caret
            echoMode: root.passwordMode ? TextInput.Password : TextInput.Normal

            onTextChanged: root.searchTextChanged(text)
            onAccepted: root.accepted()

            Keys.onPressed: event => {
                const signalName = SearchKeys.action(event.key, event.modifiers, {
                    empty: textField.text.length === 0,
                    atStart: textField.cursorPosition === 0,
                    atEnd: textField.cursorPosition === textField.text.length,
                    tabNav: root.handleTabNavigation,
                    freeCursor: root.disableCursorNavigation
                });
                if (signalName === "")
                    return;
                if (signalName === "escapePressed" && root.clearOnEscape)
                    root.clear();
                root[signalName]();
                event.accepted = true;
            }
        }

        Loader {
            active: root.trailing !== null
            visible: active
            sourceComponent: root.trailing
            Layout.alignment: Qt.AlignVCenter
        }
    }

    Divider {
        anchors.bottom: parent.bottom
        width: parent.width
        visible: root.rule && Look.dividers
    }

    Component {
        id: glyphComponent
        Icon {
            icon: root.glyph
            role: root.boxed ? "body" : "title"
            tone: "muted"
        }
    }

    Component {
        id: hintsComponent
        Row {
            spacing: Space.xs
            visible: root.text.length === 0 && root.hints.length > 0

            Repeater {
                model: root.hints
                KeyHint {
                    required property string modelData
                    text: modelData
                }
            }
        }
    }

    // A thin caret that breathes instead of blinking hard.
    Component {
        id: caret
        Rectangle {
            width: 2
            radius: 1
            color: Type.secondary
            visible: textField.cursorVisible

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: textField.cursorVisible && Motion.enter.duration > 0
                NumberAnimation {
                    from: 1
                    to: 0.15
                    duration: 600
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: 0.15
                    to: 1
                    duration: 600
                    easing.type: Easing.InOutSine
                }
            }
        }
    }
}
