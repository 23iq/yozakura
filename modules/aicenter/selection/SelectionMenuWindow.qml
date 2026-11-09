pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.globals

// Selection actions popup near the cursor (bind: `yozakura run ai-selection`).
// Up/Down + Enter or the number keys pick an action; typing goes to the
// "Ask about the selection…" field; Esc or a click outside closes.
PanelWindow {
    id: win

    required property var actions   // SelectionActions instance
    readonly property var targetScreen: Quickshell.screens.find(s => s.name === actions.screenName) || Quickshell.screens[0]

    screen: targetScreen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: Brand.appId + "-ai-selection"
    WlrLayershell.keyboardFocus: actions.working ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    property int selectedIndex: 0

    function step(delta: int) {
        const n = win.actions.actions.length;
        win.selectedIndex = Math.max(0, Math.min(n - 1, win.selectedIndex + delta));
    }

    mask: Region {
        item: win.actions.working ? menu : backdrop
    }

    MouseArea {
        id: backdrop
        anchors.fill: parent
        onClicked: win.actions.close()
    }

    Surface {
        id: menu
        objectName: "selectionMenu"
        padding: Space.s
        enableShadow: true
        width: Math.min(win.width - Space.xl * 2, win.actions.hasResult ? Config.ai.sidebarWidth : Config.ai.sidebarWidth * 0.75)
        height: implicitHeight
        readonly property point local: win.actions.cursor.x >= 0 ? Qt.point(win.actions.cursor.x - win.targetScreen.x, win.actions.cursor.y - win.targetScreen.y) : Qt.point((win.width - width) / 2, win.height / 3)
        x: Math.max(Space.s, Math.min(win.width - width - Space.s, local.x + Space.m))
        y: Math.max(Space.s, Math.min(win.height - height - Space.s, local.y + Space.l))
        focus: true

        scale: 0.96
        opacity: 0
        Component.onCompleted: {
            scale = 1;
            opacity = 1;
            ask.focusInput();
        }
        Connections {
            target: win.actions
            function onHasResultChanged() {
                if (win.actions.hasResult)
                    resultText.forceActiveFocus();
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Motion.exit.duration
                easing.type: Motion.morph.easing
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.exit.duration
            }
        }

        ColumnLayout {
            id: col
            width: parent.width
            spacing: Space.xs

            // The selected text, quoted.
            KitText {
                role: "caption"
                Layout.fillWidth: true
                Layout.leftMargin: Look.rowInset
                Layout.rightMargin: Look.rowInset
                text: "“" + win.actions.text.replace(/\s+/g, " ").substring(0, 120) + "”"
                maximumLineCount: 2
                wrapMode: Text.Wrap
                font.italic: true
            }

            RowLayout {
                visible: win.actions.working
                Layout.fillWidth: true
                Layout.margins: Look.rowInset
                spacing: Space.s
                Spinner {}
                KitText {
                    role: "secondary"
                    Layout.fillWidth: true
                    text: win.actions.workingLabel + "…"
                    color: Type.text
                }
            }

            KitText {
                role: "caption"
                visible: win.actions.error.length > 0
                Layout.fillWidth: true
                Layout.margins: Look.rowInset
                text: win.actions.error
                wrapMode: Text.Wrap
                color: Type.danger
            }

            KitText {
                visible: win.actions.hasResult
                Layout.fillWidth: true
                Layout.leftMargin: Look.rowInset
                Layout.rightMargin: Look.rowInset
                Layout.topMargin: Space.xs
                text: I18n.t("ai.selection_preview")
            }

            ScrollView {
                visible: win.actions.hasResult
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(win.height * 0.4, resultText.implicitHeight)
                clip: true
                TextArea {
                    id: resultText
                    objectName: "selectionResult"
                    text: win.actions.result
                    readOnly: true
                    selectByMouse: true
                    textFormat: TextEdit.PlainText
                    wrapMode: TextEdit.Wrap
                    font.family: Type.family("body")
                    font.pixelSize: Type.size("secondary")
                    color: Type.text
                    selectionColor: Qt.alpha(Type.accent, 0.3)
                    selectedTextColor: Type.text
                    background: StyledRect {
                        variant: "common"
                        radius: Look.radius("control")
                    }
                    Keys.onEscapePressed: win.actions.close()
                }
            }

            RowLayout {
                visible: win.actions.hasResult
                Layout.fillWidth: true
                spacing: Space.s
                // Applying the result is the one primary action here.
                Chip {
                    objectName: "selectionCopy"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    primary: true
                    icon: Icons.clipboardText
                    text: I18n.t("ai.selection_apply")
                    onClicked: win.actions.copyResult()
                }
                Chip {
                    objectName: "selectionContinue"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icon: Icons.sidebarSimple
                    text: I18n.t("ai.selection_continue")
                    onClicked: win.actions.openResult()
                }
            }

            Repeater {
                model: win.actions.working || win.actions.hasResult ? [] : win.actions.actions
                delegate: ListRow {
                    id: entry
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    // A dense menu: control-height rows, not list-height.
                    implicitHeight: Space.controlM
                    title: entry.modelData.label
                    highlighted: entry.index === win.selectedIndex
                    onClicked: win.actions.run(entry.modelData)
                    HoverHandler {
                        onHoveredChanged: if (hovered)
                            win.selectedIndex = entry.index
                    }
                    leading: Component {
                        Icon {
                            role: "body"
                            tone: "secondary"
                            icon: Icons[entry.modelData.icon] || Icons.sparkle
                        }
                    }
                    trailing: Component {
                        Row {
                            spacing: Space.s
                            // Where the result goes: replace, sidebar or clipboard.
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                role: "caption"
                                tone: "muted"
                                icon: entry.modelData.output === "sidebar" ? Icons.sidebarSimple : (entry.modelData.output === "clipboard" ? Icons.clipboardText : Icons.cursorText)
                            }
                            KeyHint {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: entry.index < 9
                                text: entry.index + 1
                            }
                        }
                    }
                }
            }

            SearchField {
                id: ask
                objectName: "selectionAsk"
                visible: !win.actions.working && !win.actions.hasResult
                Layout.fillWidth: true
                Layout.topMargin: Space.xs
                boxed: true
                glyph: Icons.sparkle
                placeholderText: I18n.t("ai.ask_selection")
                clearOnEscape: false
                onEscapePressed: win.actions.close()
                onDownPressed: win.step(1)
                onUpPressed: win.step(-1)
                onAccepted: {
                    const list = win.actions.actions;
                    if (ask.text.trim())
                        win.actions.ask(ask.text);
                    else if (list[win.selectedIndex])
                        win.actions.run(list[win.selectedIndex]);
                }
                // A digit typed into the empty field picks that action (not
                // a lone digit left over after deleting the rest of a question).
                property string previous: ""
                onSearchTextChanged: value => {
                    const wasEmpty = ask.previous === "";
                    ask.previous = value;
                    if (!wasEmpty || !/^[1-9]$/.test(value))
                        return;
                    const action = win.actions.actions[Number(value) - 1];
                    if (!action)
                        return;
                    ask.previous = "";
                    ask.clear();
                    win.actions.run(action);
                }
            }
        }
    }
}
