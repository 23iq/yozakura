import QtQuick
import QtQuick.Layouts
import qs.modules.components
import qs.modules.services
import qs.modules.theme
import qs.config
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

    implicitHeight: column.implicitHeight + root.padding * 2

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

    ColumnLayout {
        id: column
        x: root.padding
        y: root.padding
        width: parent.width - root.padding * 2
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Mic badge: breathes with the input level
            StyledRect {
                id: micBadge
                variant: root.failed ? "common" : "primary"
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: Styling.radius(20)
                enableShadow: root.listening
                scale: root.listening ? 1 + Math.min(0.18, VoiceService.level * 0.25) : 1

                Behavior on scale {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: 80
                        easing.type: Easing.OutQuad
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.transcribing ? Icons.circleNotch : root.badgeIcon()
                    font.family: Icons.font
                    font.pixelSize: 20
                    color: root.failed ? Colors.error : micBadge.item

                    RotationAnimation on rotation {
                        running: root.transcribing && root.revealed
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                    }
                    onTextChanged: rotation = 0
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: I18n.t(VoiceModel.statusKey({
                        state: root.voiceState,
                        target: VoiceService.target,
                        error: VoiceService.error
                    }) || "voice.status.listening")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(1)
                    font.weight: Font.DemiBold
                    color: root.failed ? Colors.error : Colors.overBackground
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: I18n.t(root.dictation ? "voice.target.dictation" : "voice.target.ai")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            // Language badge
            StyledRect {
                visible: !root.failed
                variant: "common"
                Layout.preferredHeight: 24
                Layout.preferredWidth: langText.implicitWidth + 16
                radius: Styling.radius(-4)

                Text {
                    id: langText
                    anchors.centerIn: parent
                    text: VoiceModel.languageBadge(VoiceService.language)
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.monoFontSize(-3)
                    font.weight: Font.Bold
                    color: Colors.primary
                }
            }

            Text {
                visible: !root.failed
                text: VoiceModel.formatElapsed(VoiceService.elapsedMs)
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.monoFontSize(-1)
                color: root.listening ? Colors.overBackground : Colors.overSurfaceVariant
                Layout.minimumWidth: 36
                horizontalAlignment: Text.AlignRight
            }
        }

        VoiceBars {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            visible: !root.showPreview && !root.failed
            bands: VoiceService.bands
            speech: VoiceService.speech
            mode: root.listening ? "live" : (root.transcribing ? "busy" : "idle")
        }

        // Transcript preview
        StyledRect {
            variant: "common"
            Layout.fillWidth: true
            Layout.preferredHeight: previewText.implicitHeight + 20
            visible: root.showPreview
            radius: Styling.radius(-2)

            Text {
                id: previewText
                anchors.fill: parent
                anchors.margins: 10
                text: VoiceService.text
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overBackground
            }
        }

        Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.hintText()
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
            opacity: 0.85
        }
    }
}
