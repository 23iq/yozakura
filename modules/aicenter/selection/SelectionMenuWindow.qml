pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.theme
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

    mask: Region {
        item: win.actions.working ? menu : backdrop
    }

    MouseArea {
        id: backdrop
        anchors.fill: parent
        onClicked: win.actions.close()
    }

    StyledRect {
        id: menu
        objectName: "selectionMenu"
        variant: "popup"
        radius: Styling.radius(0)
        enableShadow: true
        width: Math.min(win.width - Styling.fontSize(0) * 2, win.actions.hasResult ? Config.ai.sidebarWidth : Config.ai.sidebarWidth * 0.75)
        height: col.implicitHeight + 16
        readonly property point local: win.actions.cursor.x >= 0 ? Qt.point(win.actions.cursor.x - win.targetScreen.x, win.actions.cursor.y - win.targetScreen.y) : Qt.point((win.width - width) / 2, win.height / 3)
        x: Math.max(8, Math.min(win.width - width - 8, local.x + 12))
        y: Math.max(8, Math.min(win.height - height - 8, local.y + 16))
        focus: true

        scale: 0.96
        opacity: 0
        Component.onCompleted: {
            scale = 1;
            opacity = 1;
            ask.forceActiveFocus();
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
                duration: Config.animDuration / 3
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration / 3
            }
        }

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 4

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                text: "“" + win.actions.text.replace(/\s+/g, " ").substring(0, 120) + "”"
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                font.italic: true
                color: Colors.outline
            }

            RowLayout {
                visible: win.actions.working
                Layout.fillWidth: true
                Layout.margins: 6
                spacing: 8
                Spinner {}
                Text {
                    Layout.fillWidth: true
                    text: win.actions.workingLabel + "…"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overSurface
                }
            }

            Text {
                visible: win.actions.error.length > 0
                Layout.fillWidth: true
                Layout.margins: 6
                text: win.actions.error
                wrapMode: Text.Wrap
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.error
            }

            Text {
                visible: win.actions.hasResult
                Layout.fillWidth: true
                Layout.margins: Styling.fontSize(-6)
                text: I18n.t("ai.selection_preview")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overSurface
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
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overSurface
                    background: StyledRect {
                        variant: "common"
                        radius: Styling.radius(-4)
                    }
                    Keys.onEscapePressed: win.actions.close()
                }
            }

            RowLayout {
                visible: win.actions.hasResult
                Layout.fillWidth: true
                Button {
                    id: copyButton
                    objectName: "selectionCopy"
                    Layout.fillWidth: true
                    text: I18n.t("ai.selection_apply")
                    onClicked: win.actions.copyResult()
                    contentItem: Text {
                        text: copyButton.text
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overSurface
                        horizontalAlignment: Text.AlignHCenter
                    }
                    background: StyledRect {
                        variant: copyButton.hovered ? "focus" : "common"
                        radius: Styling.radius(-4)
                    }
                }
                Button {
                    id: continueButton
                    objectName: "selectionContinue"
                    Layout.fillWidth: true
                    text: I18n.t("ai.selection_continue")
                    onClicked: win.actions.openResult()
                    contentItem: Text {
                        text: continueButton.text
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overSurface
                        horizontalAlignment: Text.AlignHCenter
                    }
                    background: StyledRect {
                        variant: continueButton.hovered ? "focus" : "common"
                        radius: Styling.radius(-4)
                    }
                }
            }

            Repeater {
                model: win.actions.working || win.actions.hasResult ? [] : win.actions.actions
                delegate: StyledRect {
                    id: entry
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: Styling.radius(-6)
                    variant: entry.index === win.selectedIndex ? "focus" : (hov.hovered ? "common" : "transparent")
                    HoverHandler {
                        id: hov
                        onHoveredChanged: if (hovered)
                            win.selectedIndex = entry.index
                    }
                    TapHandler {
                        onTapped: win.actions.run(entry.modelData)
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10
                        Text {
                            text: Icons[entry.modelData.icon] || Icons.sparkle
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: Colors.primary
                        }
                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.label
                            elide: Text.ElideRight
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overSurface
                        }
                        Text {
                            text: entry.modelData.output === "sidebar" ? Icons.sidebarSimple : (entry.modelData.output === "clipboard" ? Icons.clipboardText : Icons.cursorText)
                            font.family: Icons.font
                            font.pixelSize: 11
                            color: Colors.outline
                        }
                        Text {
                            visible: entry.index < 9
                            text: entry.index + 1
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.monoFontSize(-4)
                            color: Colors.outline
                        }
                    }
                }
            }

            TextField {
                id: ask
                objectName: "selectionAsk"
                visible: !win.actions.working && !win.actions.hasResult
                Layout.fillWidth: true
                Layout.topMargin: 4
                placeholderText: I18n.t("ai.ask_selection")
                placeholderTextColor: Colors.outline
                color: Colors.overBackground
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                leftPadding: 28
                background: StyledRect {
                    variant: "common"
                    radius: Styling.radius(-4)
                    Text {
                        x: 9
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.sparkle
                        font.family: Icons.font
                        font.pixelSize: 12
                        color: Colors.primary
                    }
                }
                Keys.onPressed: event => {
                    const list = win.actions.actions;
                    if (event.key === Qt.Key_Escape) {
                        win.actions.close();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down) {
                        win.selectedIndex = Math.min(list.length - 1, win.selectedIndex + 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        win.selectedIndex = Math.max(0, win.selectedIndex - 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (ask.text.trim())
                            win.actions.ask(ask.text);
                        else if (list[win.selectedIndex])
                            win.actions.run(list[win.selectedIndex]);
                        event.accepted = true;
                    } else if (ask.text.length === 0 && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        const i = event.key - Qt.Key_1;
                        if (list[i])
                            win.actions.run(list[i]);
                        event.accepted = true;
                    }
                }
            }
        }
    }
}
