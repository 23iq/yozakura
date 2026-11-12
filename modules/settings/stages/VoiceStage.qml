pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "../../services/voice/VoiceModel.js" as VoiceModel

// Stage of Voice: your screen (ScreenMini) while you talk. The island has
// grown into the listening panel (mic, language, model, a waveform, the
// key and how it works: hold or tap), and what you said lands in a window
// as dictation (punctuation and the trailing space as set) and in the
// Assistant's field (sent at once or waiting for Enter). Off, the panel
// says so and the waveform lies flat. A click on the key switches hold /
// tap; rows light up their part.
Stage {
    id: stage

    readonly property bool on: SettingsStore.get("voice.enabled") !== false
    readonly property bool hold: SettingsStore.get("voice.activation") !== "toggle"
    readonly property string lang: String(SettingsStore.get("voice.language") || "auto")
    readonly property bool punctuation: SettingsStore.get("voice.punctuation") !== false
    readonly property bool trailing: SettingsStore.get("voice.trailingSpace") !== false
    readonly property bool autoSend: SettingsStore.get("voice.aiAutoSend") === true
    readonly property bool autoStop: SettingsStore.get("voice.vadAutoStop") !== false
    readonly property string model: String(SettingsStore.get("voice.model") || "")
    readonly property real u: mini.unit
    // a shell surface on the miniature (opaque enough over the wallpaper)
    readonly property color surface: Qt.alpha(Colors.surfaceContainer, 0.92)
    // a fixed spoken phrase, shaped the way dictation types it
    readonly property string said: {
        const t = I18n.t("prefs.voice.stage.said");
        const s = stage.punctuation ? t : t.replace(/[.,!?;:¿¡]/g, "").toLowerCase();
        return s + (stage.trailing ? " " : "");
    }

    stageHeight: Space.px(300)

    ScreenMini {
        id: mini
        anchors.fill: parent
        barOpacity: stage.barOpacity
        cornerRadius: stage.radius
        showIsland: false
        showDock: false
        showWindows: false

        // The island, grown into the voice panel.
        Mark {
            id: panel
            objectName: "voicePanel"
            readonly property bool atBottom: mini.islandEdge === "bottom"
            width: Math.round(mini.width * 0.46)
            height: Math.round(stage.u * 6.4)
            x: Math.round((mini.width - width) / 2)
            y: panel.atBottom ? mini.height - mini.edgeDepth("bottom") - height - Space.xs : Math.max(Space.xs, mini.edgeDepth("top") - stage.u * 1.2)
            radius: Math.round(stage.u * 1.3)
            color: Colors.surfaceContainerLowest
            border.width: Space.hairline
            border.color: Qt.alpha(Colors.outlineVariant, 0.7)
            opacity: stage.on ? 1 : 0.72

            // mic in its ring, the state, the target
            Mark {
                id: micRing
                x: Math.round(stage.u * 0.8)
                y: Math.round(stage.u * 0.75)
                width: Math.round(stage.u * 1.9)
                height: width
                color: stage.on ? Qt.alpha(Type.accent, 0.18) : Qt.alpha(Type.muted, 0.18)
                border.width: Math.max(2, Math.round(stage.u * 0.12))
                border.color: stage.on ? Type.accent : Type.muted
                Icon {
                    anchors.centerIn: parent
                    icon: stage.on ? Icons.mic : Icons.micSlash
                    size: Math.round(stage.u * 0.95)
                    tone: stage.on ? "accent" : "muted"
                }
            }
            Column {
                anchors.left: micRing.right
                anchors.leftMargin: Math.round(stage.u * 0.55)
                anchors.right: badges.left
                anchors.rightMargin: Space.s
                anchors.verticalCenter: micRing.verticalCenter
                spacing: Math.round(stage.u * 0.08)
                KitText {
                    width: parent.width
                    role: "title"
                    font.pixelSize: Math.round(stage.u * 0.72)
                    elide: Text.ElideRight
                    text: I18n.t(stage.on ? "voice.status.listening" : "voice.settings.disabled")
                }
                KitText {
                    width: parent.width
                    visible: stage.on
                    role: "secondary"
                    font.pixelSize: Math.round(stage.u * 0.55)
                    elide: Text.ElideRight
                    text: I18n.t("voice.target.ai")
                }
            }
            Row {
                id: badges
                anchors.right: parent.right
                anchors.rightMargin: Math.round(stage.u * 0.8)
                anchors.verticalCenter: micRing.verticalCenter
                spacing: Math.round(stage.u * 0.3)
                visible: stage.on
                Pill {
                    id: langPill
                    text: VoiceModel.languageBadge(stage.lang)
                    StageSpot {
                        keys: ["voice.language"]
                        cornerRadius: langPill.radius
                    }
                }
                Pill {
                    id: modelPill
                    text: I18n.t("prefs.voice.model." + stage.model) || stage.model
                    StageSpot {
                        keys: ["voice.model", "voice.useGpu"]
                        cornerRadius: modelPill.radius
                    }
                }
            }

            // the waveform: still, drawn from a fixed phrase shape
            Row {
                id: wave
                anchors.horizontalCenter: parent.horizontalCenter
                y: micRing.y + micRing.height + Math.round(stage.u * 0.55)
                height: Math.round(stage.u * 1.7)
                spacing: Math.max(2, Math.round(stage.u * 0.18))
                Repeater {
                    model: 30
                    delegate: Mark {
                        required property int index
                        // speech, a pause, speech: auto-stop shows the tail
                        readonly property real level: {
                            const i = index;
                            const env = i < 12 ? Math.sin(i / 11 * Math.PI) : (i < 16 ? 0.12 : Math.sin((i - 16) / 13 * Math.PI) * 0.8);
                            const jitter = 0.55 + 0.45 * Math.abs(Math.sin(i * 2.7));
                            return Math.max(0.1, env * jitter);
                        }
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(2, Math.round(stage.u * 0.22))
                        height: stage.on ? Math.max(width, wave.height * level) : width
                        color: stage.on ? (index > 26 && stage.autoStop ? Qt.alpha(Type.accent, 0.35) : Type.accent) : Type.muted
                        Behavior on height {
                            enabled: Motion.glide.duration > 0
                            NumberAnimation {
                                duration: Motion.glide.duration
                                easing.type: Motion.glide.easing
                            }
                        }
                    }
                }
            }
            StageSpot {
                anchors.fill: wave
                keys: ["voice.vadAutoStop", "voice.enabled"]
            }

            // the key and how it works; a click switches hold / tap
            Row {
                id: keyRow
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(stage.u * 0.6)
                spacing: Math.round(stage.u * 0.3)
                opacity: stage.on ? 1 : 0.5
                KeyHint {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("prefs.voice.stage.super")
                }
                KeyHint {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "M"
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: stage.hold ? Icons.hand : Icons.mouseLeftClick
                    role: "caption"
                    tone: "accent"
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "caption"
                    color: Type.text
                    text: I18n.t(stage.hold ? "prefs.voice.stage.hold" : "prefs.voice.stage.tap")
                }
            }
            StageSpot {
                anchors.fill: keyRow
                anchors.margins: -Space.xs
                keys: ["voice.activation"]
            }
            MouseArea {
                objectName: "voiceActivationFlip"
                anchors.fill: keyRow
                anchors.margins: -Space.xs
                enabled: stage.on
                cursorShape: Qt.PointingHandCursor
                onClicked: SettingsStore.transaction("prefs.undo.voice_activation", () => SettingsStore.set("voice.activation", stage.hold ? "toggle" : "push-to-talk"))
            }
        }

        // Where the words land: a window you dictate into, and the
        // Assistant's field.
        Item {
            id: targets
            readonly property real startY: panel.atBottom ? mini.freeRect.y + stage.u : panel.y + panel.height + stage.u * 0.9
            readonly property real bottomEdge: panel.atBottom ? panel.y - stage.u * 0.9 : mini.freeRect.y + mini.freeRect.h - stage.u
            readonly property real room: Math.max(stage.u * 3, targets.bottomEdge - targets.startY)
            x: mini.freeRect.x + mini.freeRect.w * 0.08
            y: targets.startY + (targets.room - height) / 2
            width: mini.freeRect.w * 0.84
            height: Math.min(targets.room, stage.u * 5.6)
            opacity: stage.on ? 1 : 0.45

            // dictation into a text window
            Mark {
                id: doc
                objectName: "voiceDictation"
                width: Math.round(targets.width * 0.54)
                height: targets.height
                radius: Look.radius("box", Math.min(height, stage.u * 4))
                color: stage.surface
                border.width: Space.hairline
                border.color: Qt.alpha(Colors.outlineVariant, 0.7)
                Row {
                    x: Math.round(stage.u * 0.7)
                    y: Math.round(stage.u * 0.6)
                    spacing: Math.round(stage.u * 0.3)
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Icons.keyboard
                        size: Math.round(stage.u * 0.7)
                        tone: "secondary"
                    }
                    KitText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "caption"
                        font.pixelSize: Math.round(stage.u * 0.55)
                        text: I18n.t("voice.target.dictation")
                    }
                }
                Row {
                    id: typed
                    x: Math.round(stage.u * 0.7)
                    y: Math.round(stage.u * 2)
                    width: doc.width - stage.u * 1.4
                    spacing: 0
                    KitText {
                        id: saidText
                        role: "body"
                        font.pixelSize: Math.round(stage.u * 0.72)
                        // a trailing space shows as room before the caret
                        text: stage.said.replace(/ $/, " ")
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, typed.width - caret.width)
                    }
                    Mark {
                        id: caret
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(2, Math.round(stage.u * 0.1))
                        height: Math.round(stage.u * 0.95)
                        radius: 0
                        color: Type.accent
                    }
                }
                StageSpot {
                    anchors.fill: typed
                    anchors.margins: -Space.xs
                    keys: ["voice.punctuation", "voice.trailingSpace", "voice.typingMethod"]
                }
            }

            // the Assistant: sent at once, or in the field until Enter
            Mark {
                id: chat
                objectName: "voiceAssistant"
                anchors.right: parent.right
                width: targets.width - doc.width - stage.u
                height: targets.height
                radius: doc.radius
                color: stage.surface
                border.width: Space.hairline
                border.color: Qt.alpha(Colors.outlineVariant, 0.7)
                Row {
                    x: Math.round(stage.u * 0.7)
                    y: Math.round(stage.u * 0.6)
                    spacing: Math.round(stage.u * 0.3)
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Icons.sparkle
                        size: Math.round(stage.u * 0.7)
                        tone: "accent"
                    }
                    KitText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "caption"
                        font.pixelSize: Math.round(stage.u * 0.55)
                        text: I18n.t("prefs.dest.assistant")
                    }
                }
                // sent: your bubble
                Mark {
                    id: bubble
                    visible: stage.autoSend
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(stage.u * 0.6)
                    y: Math.round(stage.u * 2)
                    width: Math.min(parent.width - stage.u * 1.2, bubbleText.implicitWidth + stage.u * 1.2)
                    height: bubbleText.implicitHeight + stage.u * 0.6
                    radius: Look.radius("box", height)
                    color: Type.accent
                    KitText {
                        id: bubbleText
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, chat.width - stage.u * 2.4)
                        role: "body"
                        font.pixelSize: Math.round(stage.u * 0.62)
                        color: Type.accentInk
                        elide: Text.ElideRight
                        text: I18n.t("prefs.voice.stage.said")
                    }
                }
                // waiting: in the field, Enter sends
                Mark {
                    id: field
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Math.round(stage.u * 0.5)
                    height: Math.round(stage.u * 1.6)
                    radius: Look.radius("control", height)
                    color: Qt.alpha(Colors.surfaceContainerHighest, 0.8)
                    KitText {
                        anchors.left: parent.left
                        anchors.leftMargin: Math.round(stage.u * 0.5)
                        anchors.right: send.left
                        anchors.rightMargin: Space.xs
                        anchors.verticalCenter: parent.verticalCenter
                        role: "caption"
                        font.pixelSize: Math.round(stage.u * 0.55)
                        color: stage.autoSend ? Type.muted : Type.text
                        elide: Text.ElideRight
                        text: stage.autoSend ? I18n.t("prefs.voice.stage.ask") : I18n.t("prefs.voice.stage.said")
                    }
                    Mark {
                        id: send
                        anchors.right: parent.right
                        anchors.rightMargin: Math.round(stage.u * 0.25)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(stage.u * 1.1)
                        height: width
                        color: stage.autoSend ? Qt.alpha(Type.muted, 0.3) : Type.accent
                        Icon {
                            anchors.centerIn: parent
                            icon: stage.autoSend ? Icons.check : Icons.paperPlaneRight
                            size: Math.round(stage.u * 0.6)
                            tone: stage.autoSend ? "muted" : "accentInk"
                        }
                    }
                }
                StageSpot {
                    anchors.fill: chat
                    keys: ["voice.aiAutoSend"]
                    cornerRadius: chat.radius
                }
            }
        }
    }

    // A small label pill of the panel (language, model).
    component Pill: Mark {
        id: pill
        property string text: ""
        width: pillText.implicitWidth + stage.u * 0.7
        height: Math.round(stage.u * 0.95)
        radius: Look.radius("chip", height)
        color: "transparent"
        border.width: Space.hairline
        border.color: Qt.alpha(Type.muted, 0.6)
        KitText {
            id: pillText
            anchors.centerIn: parent
            role: "caption"
            font.pixelSize: Math.round(stage.u * 0.48)
            font.weight: Font.Medium
            color: Type.secondary
            text: pill.text
        }
    }
}
