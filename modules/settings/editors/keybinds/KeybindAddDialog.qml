pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.keybinds
import qs.modules.settings
import qs.config
import "../../Ui.js" as Ui
import "../../../keybinds/BindModel.js" as BindModel
import "../../../../config/KeybindActions.js" as KeybindActions
import qs.modules.components.kit

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
        width: Math.min((parent ? parent.width : 640) - Space.xxl * 2, 600)
        height: Math.min((parent ? parent.height : 800) - Space.xxl * 2, body.implicitHeight + topPadding + bottomPadding)
        padding: Space.xl
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

        background: StyledRect {
            variant: "popup"
            radius: Look.radius("surface")
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
                spacing: Space.l

                Keys.onEscapePressed: root.cancel()
                Keys.onReturnPressed: root.save()
                Keys.onEnterPressed: root.save()

                KitText {
                    role: "title"
                    Layout.fillWidth: true
                    text: I18n.t("binds.add_keybind")
                    font.weight: Font.Bold
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
                    Layout.leftMargin: Space.xxl
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
                    Layout.leftMargin: Space.xxl
                    action: root.action
                    onEdited: a => root.setAction(a)
                }

                Divider {
                    Layout.fillWidth: true
                    Layout.topMargin: Space.xs / 2
                }

                // Where it will be listed (or what is still missing), then
                // Cancel / Save.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Space.m

                    Icon {
                        role: "secondary"
                        tone: "accent"
                        visible: root.missing === ""
                        icon: Icons[BindModel.group(root.groupId).icon] ?? ""
                    }
                    KitText {
                        objectName: "keybindAddStatus"
                        role: "caption"
                        Layout.fillWidth: true
                        text: root.missing === "" ? I18n.t("binds.add_lands_in", I18n.t(BindModel.group(root.groupId).title)) : root.missingText()
                        wrapMode: Text.Wrap
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

                KitText {
                    role: "caption"
                    Layout.fillWidth: true
                    text: I18n.t("binds.add_more_hint")
                    wrapMode: Text.Wrap
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
        spacing: Space.m

        // Progress marker: a filled accent dot once the step is done.
        Rectangle {
            implicitWidth: Space.xl
            implicitHeight: Space.xl
            radius: Look.radius("round", height)
            color: step.done ? Type.progress : Qt.alpha(Type.progress, Look.activeTint)
            Icon {
                anchors.centerIn: parent
                visible: step.done
                icon: Icons.accept
                role: "caption"
                tone: "accentInk"
            }
            KitText {
                anchors.centerIn: parent
                visible: !step.done
                role: "caption"
                text: String(step.number)
                font.weight: Font.Bold
                color: Type.progress
            }
        }
        KitText {
            Layout.fillWidth: true
            text: step.title
            font.weight: Font.DemiBold
        }
    }
}
