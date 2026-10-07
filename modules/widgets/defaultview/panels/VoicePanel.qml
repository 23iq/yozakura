import QtQuick
import qs.modules.components.kit
import qs.modules.services
import qs.modules.theme
import "../../../services/voice/VoiceModel.js" as VoiceModel

// Notch panel "voice" (NotchPanels.js: auto + modal): opens by itself while
// voice input is active (VoiceService.panelOpen) with the live spectrum,
// elapsed time, language badge, "transcribing…" state and the text
// preview. Dismissing it (Esc, click outside, another view) cancels the
// session; Enter finishes early.
NotchPanel {
    id: root

    readonly property string voiceState: VoiceService.state
    readonly property bool listening: voiceState === "listening"
    readonly property bool transcribing: voiceState === "transcribing"
    readonly property bool dictation: VoiceService.target === "dictation"
    readonly property bool failed: voiceState === "error" || voiceState === "empty"
    readonly property bool showPreview: voiceState === "done" && VoiceService.text !== ""

    implicitHeight: root.topPadding + group.implicitHeight + root.padding

    onDismissed: VoiceService.dismiss()

    Keys.onReturnPressed: event => {
        if (root.listening)
            VoiceService.stop();
        event.accepted = true;
    }

    function hintText(): string {
        if (root.listening) {
            if (VoiceService.activation === "push-to-talk" && !VoiceService.handsFree)
                return I18n.t("voice.hint.release");
            return I18n.t("voice.hint.hands_free");
        }
        if (root.transcribing)
            return I18n.t("voice.hint.cancel");
        if (VoiceService.state === "error" && VoiceService.error === "not_installed")
            return I18n.t("voice.hint.setup");
        return "";
    }

    function badgeIcon(): string {
        if (root.failed)
            return Icons.alert;
        if (root.voiceState === "done")
            return root.dictation ? Icons.keyboard : Icons.sparkle;
        return Icons.mic;
    }

    Group {
        id: group
        x: root.padding
        y: root.topPadding
        width: parent.width - root.padding * 2

        Item {
            width: parent.width
            height: Math.max(badge.height, titles.implicitHeight)

            // Mic in a Ring that follows the input level
            Ring {
                id: badge
                width: Space.controlM
                height: Space.controlM
                anchors.verticalCenter: parent.verticalCenter
                value: root.listening ? Math.min(1, VoiceService.level * 1.4) : (root.transcribing ? 0.25 : 0)
                rotation: 0

                RotationAnimation on rotation {
                    running: root.transcribing && root.revealed
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    onStopped: badge.rotation = 0
                }

                Text {
                    text: root.badgeIcon()
                    rotation: -badge.rotation
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("body")
                    color: root.failed ? Colors.error : (root.listening ? Type.accent : Type.secondary)
                }
            }

            Column {
                id: titles
                anchors.left: badge.right
                anchors.leftMargin: Space.m
                anchors.right: meta.left
                anchors.rightMargin: Space.m
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                KitText {
                    width: parent.width
                    role: "title"
                    color: root.failed ? Colors.error : Type.text
                    text: I18n.t(VoiceModel.statusKey({
                        state: root.voiceState,
                        target: VoiceService.target,
                        error: VoiceService.error
                    }) || "voice.status.listening")
                }
                KitText {
                    width: parent.width
                    role: "secondary"
                    text: I18n.t(root.dictation ? "voice.target.dictation" : "voice.target.ai")
                }
            }

            Row {
                id: meta
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.s
                visible: !root.failed

                KeyHint {
                    anchors.verticalCenter: parent.verticalCenter
                    text: VoiceModel.languageBadge(VoiceService.language)
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "secondary"
                    tabular: true
                    color: root.listening ? Type.text : Type.secondary
                    text: VoiceModel.formatElapsed(VoiceService.elapsedMs)
                }
            }
        }

        VoiceBars {
            objectName: "voiceBars"
            width: parent.width
            height: Space.xxl + Space.s
            visible: !root.showPreview && !root.failed
            bands: VoiceService.bands
            speech: VoiceService.speech
            mode: root.listening ? "live" : (root.transcribing ? "busy" : "idle")
        }

        // Transcript preview
        KitText {
            width: parent.width
            visible: root.showPreview
            role: "body"
            text: VoiceService.text
            wrapMode: Text.Wrap
            maximumLineCount: 4
        }

        KitText {
            width: parent.width
            visible: text !== ""
            role: "caption"
            text: root.hintText()
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
