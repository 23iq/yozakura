pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.keybinds
import qs.modules.settings
import qs.config
import "../../Ui.js" as Ui
import "../../../keybinds/BindModel.js" as BindModel
import "../../../../config/KeybindActions.js" as KeybindActions

// "Add shortcut": a modal over the settings window. Step 1 records the keys
// (KeyRecorder, starts right away), step 2 picks what they do: one search
// over actions and installed apps ("firefox" offers Open Firefox,
// "fullscreen" Toggle Fullscreen), then the action's own fields. A combo
// another bind uses is marked live but never blocked: both binds are kept.
// Save adds the bind to the group of its action (BindModel.actionGroup) and
// the list scrolls to it; Cancel, Esc or a click outside drop it. A name,
// more combos/actions and layout limits are in the bind's editor.
Item {
    id: root

    objectName: "keybindAddDialog"

    property var keys: [root.emptyKey()]
    property var action: root.emptyAction()
    readonly property bool opened: popup.visible
    readonly property var actions: action.id ? [action] : []
    // "keys" | "action" | an empty field's key | "" (ready)
    readonly property string missing: BindModel.missingPart(keys, actions)
    readonly property string groupId: action.id ? BindModel.bindGroup(actions) : ""
    signal saved(string uid)

    function emptyKey() {
        return {
            "modifiers": [],
            "key": ""
        };
    }

    function emptyAction() {
        return {
            "id": "",
            "args": {},
            "layouts": []
        };
    }

    function open() {
        keys = [emptyKey()];
        action = emptyAction();
        popup.open();
    }

    function cancel() {
        popup.close();
    }

    function setKey(k) {
        keys = [k];
        if (!action.id)
            Qt.callLater(actionEditor.openPicker);
        else
            body.forceActiveFocus();
    }

    function setAction(a) {
        action = a;
        body.forceActiveFocus();
    }

    // Returns the new bind's uid ("" while something is missing).
    function save() {
        if (missing !== "")
            return "";
        const uid = KeybindsStore.addBind("", keys, actions);
        popup.close();
        saved(uid);
        return uid;
    }

    function missingText() {
        if (missing === "keys")
            return I18n.t("binds.add_need_keys");
        if (missing === "action")
            return I18n.t("binds.add_need_action");
        return I18n.t("binds.add_need_field", I18n.t(KeybindActions.fieldLabelKey(missing)));
    }

    Popup {
        id: popup

        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min((parent ? parent.width : 640) - 48, 600)
        height: Math.min((parent ? parent.height : 800) - 48, body.implicitHeight + topPadding + bottomPadding)
        padding: 22
        modal: true
        focus: true
        // Esc is handled below: it first stops a recording or closes a list.
        closePolicy: Popup.CloseOnPressOutside

        onOpened: recorder.start()
        onClosed: {
            if (recorder.recording)
                recorder.cancel();
        }

        Overlay.modal: Rectangle {
            color: Ui.alpha(Colors.shadow, 0.45)
        }

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Math.max(1, Config.animDuration / 2)
            }
            NumberAnimation {
                property: "scale"
                from: 0.96
                to: 1
                duration: Math.max(1, Config.animDuration / 2)
                easing.type: Motion.enter.easing
            }
        }
        exit: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: Math.max(1, Config.animDuration / 3)
            }
        }

        background: Rectangle {
            radius: Math.min(Styling.radius(6), 26)
            color: Colors.surfaceContainerHigh
            border.width: 1
            border.color: Ui.alpha(Colors.outline, 0.35)
        }

        contentItem: Flickable {
            contentWidth: width
            contentHeight: body.implicitHeight
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            ColumnLayout {
                id: body
                objectName: "keybindAddBody"
                width: parent.width
                spacing: 16

                Keys.onEscapePressed: root.cancel()
                Keys.onReturnPressed: root.save()
                Keys.onEnterPressed: root.save()

                Text {
                    Layout.fillWidth: true
                    text: I18n.t("binds.add_keybind")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(3)
                    font.weight: Font.Bold
                    color: Colors.overBackground
                }

                // 1. Keys
                Step {
                    number: 1
                    title: I18n.t("binds.add_step_keys")
                    done: root.missing !== "keys"
                }
                KeyRecorder {
                    id: recorder
                    Layout.fillWidth: true
                    Layout.leftMargin: 34
                    combo: root.keys[0]
                    exceptUid: ""
                    onCommitted: k => root.setKey(k)
                }

                // 2. Action
                Step {
                    number: 2
                    title: I18n.t("binds.add_step_action")
                    done: root.missing !== "keys" && root.missing !== "action"
                }
                ActionEditor {
                    id: actionEditor
                    Layout.fillWidth: true
                    Layout.leftMargin: 34
                    action: root.action
                    onEdited: a => root.setAction(a)
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    implicitHeight: 1
                    color: Ui.alpha(Colors.outlineVariant, 0.5)
                }

                // Where it will be listed (or what is still missing), then
                // Cancel / Save.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        visible: root.missing === ""
                        text: Icons[BindModel.group(root.groupId).icon] ?? ""
                        font.family: Icons.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.primary
                    }
                    Text {
                        objectName: "keybindAddStatus"
                        Layout.fillWidth: true
                        text: root.missing === "" ? I18n.t("binds.add_lands_in", I18n.t(BindModel.group(root.groupId).title)) : root.missingText()
                        wrapMode: Text.Wrap
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overSurfaceVariant
                    }
                    PillButton {
                        kind: "ghost"
                        text: I18n.t("common.cancel")
                        onClicked: root.cancel()
                    }
                    PillButton {
                        objectName: "keybindAddSave"
                        kind: "filled"
                        icon: "accept"
                        text: I18n.t("common.save")
                        enabled: root.missing === ""
                        onClicked: root.save()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: I18n.t("binds.add_more_hint")
                    wrapMode: Text.Wrap
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
                    color: Colors.outline
                }
            }
        }
    }

    // A numbered step title; the number turns into a check once done.
    component Step: RowLayout {
        id: step
        property int number: 1
        property string title: ""
        property bool done: false

        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            implicitWidth: 24
            implicitHeight: 24
            radius: 12
            color: step.done ? Colors.primary : Ui.alpha(Colors.primary, 0.16)
            Text {
                anchors.centerIn: parent
                text: step.done ? Icons.accept : String(step.number)
                font.family: step.done ? Icons.font : Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.Bold
                color: step.done ? Colors.overPrimary : Colors.primary
            }
        }
        Text {
            Layout.fillWidth: true
            text: step.title
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            font.weight: Font.DemiBold
            color: Colors.overBackground
        }
    }
}
