pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Polkit
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// The polkit password card: what is being authorised (the polkit message,
// the action id under it), who authenticates (a picker only with more
// than one identity), the prompt polkit asks (masked unless
// responseVisible), its info / error lines (fingerprint prompts, a wrong
// password) and Cancel / Authenticate. Enter submits, Escape cancels; the
// field has the focus and is emptied the moment it is submitted (the typed
// value only passes through submit()), and focused again for a retry.
FocusScope {
    id: root

    property AuthFlow flow
    property bool shown: true
    readonly property var identities: root.identityList()
    readonly property bool canAnswer: root.flow !== null && root.flow.isResponseRequired && !root.flow.isCompleted
    readonly property bool noticeIsError: root.flow !== null && (root.flow.supplementaryMessage !== "" ? root.flow.supplementaryIsError : root.flow.failed)
    readonly property string notice: {
        if (!root.flow)
            return "";
        if (root.flow.supplementaryMessage !== "")
            return root.flow.supplementaryMessage;
        if (root.flow.failed)
            return I18n.t("polkit.failed");
        return root.flow.isResponseRequired ? "" : I18n.t("polkit.waiting");
    }
    // "Password: " -> "Password"
    readonly property string prompt: {
        const p = root.flow ? root.flow.inputPrompt.trim().replace(/:$/, "").trim() : "";
        return p !== "" ? p : I18n.t("polkit.password");
    }

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight
    opacity: root.shown ? 1 : 0
    scale: root.shown ? 1 : 0.96

    Behavior on opacity {
        enabled: Motion.enter.duration > 0
        NumberAnimation {
            duration: Motion.enter.duration
            easing.type: Motion.enter.easing
        }
    }
    Behavior on scale {
        enabled: Motion.enter.duration > 0
        NumberAnimation {
            duration: Motion.enter.duration
            easing.type: Motion.enter.easing
        }
    }

    function identityList(): var {
        const out = [];
        const list = root.flow ? root.flow.identities : null;
        for (let i = 0; list && i < list.length; i++)
            out.push(list[i]);
        return out;
    }

    function identityName(identity: var): string {
        if (!identity)
            return "";
        return identity.displayName || identity.string || String(identity.id);
    }

    function focusField() {
        field.focusInput();
    }

    function submit() {
        if (!root.canAnswer)
            return;
        const value = field.text;
        field.clear();
        root.flow.submit(value);
    }

    function cancel() {
        if (root.flow && !root.flow.isCompleted)
            root.flow.cancelAuthenticationRequest();
    }

    // A new request (the next in polkit's queue) starts clean.
    onFlowChanged: {
        field.clear();
        Qt.callLater(root.focusField);
    }
    Component.onCompleted: Qt.callLater(root.focusField)

    Connections {
        target: root.flow
        function onAuthenticationFailed() {
            field.clear();
            root.focusField();
        }
        function onIsResponseRequiredChanged() {
            if (root.flow.isResponseRequired)
                root.focusField();
        }
    }

    Keys.onEscapePressed: root.cancel()

    Surface {
        id: card
        // Edge to text as in the language's grouped surfaces
        padding: Look.contentInset

        Column {
            id: body
            width: Space.px(400)
            spacing: Space.m

            Row {
                width: parent.width
                spacing: Space.s

                Icon {
                    id: glyph
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.shieldCheck
                    role: "title"
                    tone: "secondary"
                }
                KitText {
                    objectName: "polkitTitle"
                    width: parent.width - glyph.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    role: "title"
                    text: I18n.t("polkit.title")
                }
            }

            Column {
                width: parent.width
                spacing: Space.xs

                KitText {
                    objectName: "polkitMessage"
                    width: parent.width
                    role: "body"
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    text: root.flow ? root.flow.message : ""
                }
                KitText {
                    objectName: "polkitAction"
                    width: parent.width
                    visible: text !== ""
                    role: "caption"
                    color: Type.muted
                    elide: Text.ElideMiddle
                    font.family: Type.monoFont
                    text: root.flow ? root.flow.actionId : ""
                }
            }

            // One identity: named; several: picked.
            KitText {
                objectName: "polkitIdentity"
                width: parent.width
                visible: root.identities.length === 1
                role: "secondary"
                text: root.identities.length === 1 ? I18n.t("polkit.as_user", root.identityName(root.identities[0])) : ""
            }
            Column {
                width: parent.width
                visible: root.identities.length > 1
                spacing: Space.xs

                KitText {
                    role: "caption"
                    text: I18n.t("polkit.identity")
                }
                Dropdown {
                    objectName: "polkitIdentityPicker"
                    width: parent.width
                    options: root.identities.map((identity, i) => ({
                                "value": i,
                                "text": root.identityName(identity),
                                "icon": Icons.user
                            }))
                    value: root.flow ? root.identities.indexOf(root.flow.selectedIdentity) : -1
                    onSelected: v => {
                        if (root.flow && root.identities[v])
                            root.flow.selectedIdentity = root.identities[v];
                        root.focusField();
                    }
                }
            }

            SearchField {
                id: field
                objectName: "polkitField"
                width: parent.width
                boxed: true
                glyph: Icons.lock
                hints: []
                clearOnEscape: false
                passwordMode: !(root.flow && root.flow.responseVisible)
                placeholderText: root.prompt
                enabled: root.canAnswer
                onAccepted: root.submit()
                onEscapePressed: root.cancel()
            }

            KitText {
                objectName: "polkitNotice"
                width: parent.width
                visible: root.notice !== ""
                role: "caption"
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                color: root.noticeIsError ? Type.danger : Type.secondary
                text: root.notice
            }

            Item {
                width: parent.width
                height: buttons.height

                Row {
                    id: buttons
                    anchors.right: parent.right
                    spacing: Space.s

                    Chip {
                        objectName: "polkitCancel"
                        icon: Icons.cancel
                        text: I18n.t("polkit.cancel")
                        onClicked: root.cancel()
                    }
                    Chip {
                        objectName: "polkitAuthenticate"
                        primary: true
                        icon: Icons.accept
                        text: I18n.t("polkit.authenticate")
                        enabled: root.canAnswer
                        onClicked: root.submit()
                    }
                }
            }
        }
    }
}
