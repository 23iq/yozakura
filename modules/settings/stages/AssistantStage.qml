pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Stage of Chat: the Assistant's chat itself on a plain ground, drawn from
// the live options: the status line with what it shows (model, effort,
// context, cost, limit; a click on an item shows or hides it), a question
// and its answer as bubbles or flat text, at the density and text size,
// avatars and times, the folded thinking line, the suggestion chips and
// the field. Off, the panel is a faint ghost. Its side and size are rows.
Stage {
    id: stage

    // the chat's unit at this stage's scale (its text is 0.6 of it)
    readonly property real u: Space.px(24)
    // a strip as wide as the page (SettingsPage)
    readonly property bool pageWide: true
    readonly property real preferredHeight: Space.px(250)
    readonly property bool on: SettingsStore.get("ai.enabled") !== false
    readonly property string side: SettingsStore.get("ai.sidebarPosition") === "left" ? "left" : "right"
    readonly property string size: String(SettingsStore.get("ai.appearance.defaultSize") || "compact")
    readonly property bool bubbles: SettingsStore.get("ai.appearance.messageStyle") !== "flat"
    readonly property bool dense: SettingsStore.get("ai.appearance.density") === "compact"
    readonly property real fontScale: Math.max(0.8, Math.min(1.4, Number(SettingsStore.get("ai.appearance.fontScale") ?? 1)))
    readonly property bool avatars: SettingsStore.get("ai.appearance.showAvatars") === true
    readonly property bool times: SettingsStore.get("ai.appearance.showTimestamps") === true
    readonly property bool glass: SettingsStore.get("ai.appearance.glass") !== false
    readonly property bool thinking: SettingsStore.get("ai.showThinking") !== false
    readonly property bool suggestions: SettingsStore.get("ai.behavior.suggestions") !== false
    readonly property var strip: ({
            "engine": SettingsStore.get("ai.strip.engine") !== false,
            "effort": SettingsStore.get("ai.strip.effort") !== false,
            "context": SettingsStore.get("ai.strip.context") !== false,
            "cost": SettingsStore.get("ai.strip.cost") !== false,
            "limit": SettingsStore.get("ai.strip.limit") !== false
        })
    // the chat's text and its spacing
    readonly property real fs: Math.round(stage.u * 0.6 * stage.fontScale)
    readonly property real gap: Math.round(stage.u * (stage.dense ? 0.3 : 0.6))
    // the default model by its id ("provider:model"), without waking the
    // AI service
    readonly property string modelName: {
        const id = String(SettingsStore.get("ai.defaultModel") || "");
        return id ? id.slice(id.indexOf(":") + 1) : I18n.t("prefs.ai.stage.model");
    }

    // what a strip item reads
    function stripText(key) {
        switch (key) {
        case "engine":
            return stage.modelName.length > 16 ? stage.modelName.slice(0, 15) + "…" : stage.modelName;
        case "effort":
            return I18n.t("ai.effort_level.high");
        case "context":
            return "12%";
        case "cost":
            return "$0.04";
        }
        return "35%";
    }

    stageHeight: stage.preferredHeight

    // The Assistant, on its side at its size.
    Mark {
        id: panel
        objectName: "assistantPanel"
        // over the edge targets: its own parts take the clicks
        z: 1
        readonly property real m: Math.round(stage.u * 0.35)
        // as wide as its size reads (a sidebar, wide), centred
        width: Math.round(Math.min(stage.width - Space.xl * 2, stage.u * (stage.size === "compact" ? 22 : 34)))
        height: stage.height - Space.m * 2
        anchors.centerIn: parent
        radius: Look.radius("surface", Math.min(height, stage.u * 6))
        color: Qt.alpha(Colors.surfaceContainer, stage.glass ? 0.84 : 0.98)
        border.width: Space.hairline
        border.color: Qt.alpha(Colors.outlineVariant, 0.7)
        opacity: stage.on ? 1 : 0.35
        clip: true
        Behavior on width {
            enabled: Motion.glide.duration > 0
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }

        // the status strip: what is on, and a dashed ghost for what is
        // off; a click on an item shows or hides it
        Flow {
            id: statusRow
            objectName: "assistantStrip"
            x: Math.round(stage.u * 0.6)
            y: Math.round(stage.u * 0.5)
            width: panel.width - x * 2
            spacing: Math.round(stage.u * 0.25)
            Repeater {
                model: [
                    {
                        "key": "engine",
                        "icon": "sparkle"
                    },
                    {
                        "key": "effort",
                        "icon": "brain"
                    },
                    {
                        "key": "context",
                        "icon": "circleHalf"
                    },
                    {
                        "key": "cost",
                        "icon": "chartBar"
                    },
                    {
                        "key": "limit",
                        "icon": "hourglass"
                    }
                ]
                delegate: Pill {
                    id: item
                    required property var modelData
                    readonly property bool shown: stage.strip[item.modelData.key] === true
                    objectName: "assistantStrip:" + item.modelData.key
                    icon: Icons[item.modelData.icon] ?? ""
                    text: item.shown ? stage.stripText(item.modelData.key) : ""
                    accent: item.shown && item.modelData.key === "engine"
                    ghost: !item.shown
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsStore.transaction("prefs.undo.strip_changed", () => SettingsStore.set("ai.strip." + item.modelData.key, !item.shown))
                    }
                }
            }
        }
        StageSpot {
            anchors.fill: statusRow
            anchors.margins: -Space.xs
            keys: ["ai.strip", "ai.defaultModel"]
        }

        // the conversation
        Column {
            id: chat
            x: Math.round(stage.u * 0.6)
            y: statusRow.y + statusRow.height + Math.round(stage.u * 0.6)
            width: panel.width - x * 2
            spacing: stage.gap

            // your question
            Message {
                mine: true
                text: I18n.t("prefs.ai.stage.ask")
                time: "21:46"
            }
            // the thinking line, folded
            Row {
                visible: stage.thinking
                spacing: Math.round(stage.u * 0.25)
                x: stage.avatars ? Math.round(stage.u * 1.3) : 0
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.caretRight
                    size: Math.round(stage.fs * 0.9)
                    tone: "muted"
                }
                KitText {
                    role: "caption"
                    font.pixelSize: Math.round(stage.fs * 0.9)
                    font.italic: true
                    color: Type.muted
                    text: I18n.t("prefs.ai.stage.thought")
                }
            }
            // the answer
            Message {
                mine: false
                text: I18n.t("prefs.ai.stage.answer")
                time: "21:47"
            }
        }
        StageSpot {
            anchors.fill: chat
            anchors.margins: -Space.xs
            keys: ["ai.appearance", "ai.showThinking"]
        }

        // suggestions, then the field
        Flow {
            id: chips
            // only where it has room under the answer (never over it)
            visible: stage.suggestions && chips.y >= chat.y + chat.height + stage.gap
            x: Math.round(stage.u * 0.6)
            width: panel.width - x * 2
            anchors.bottom: field.top
            anchors.bottomMargin: Math.round(stage.u * 0.4)
            spacing: Math.round(stage.u * 0.3)
            Pill {
                icon: Icons.clipboardText
                text: I18n.t("prefs.ai.stage.sug_clip")
            }
            Pill {
                icon: Icons.musicNotes
                text: I18n.t("prefs.ai.stage.sug_song")
            }
        }
        StageSpot {
            anchors.fill: chips
            anchors.margins: -Space.xs
            visible: stage.suggestions
            keys: ["ai.behavior.suggestions"]
        }
        Mark {
            id: field
            x: Math.round(stage.u * 0.5)
            width: panel.width - x * 2
            height: Math.round(stage.u * 1.6)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(stage.u * 0.5)
            radius: Look.radius("control", height)
            color: Qt.alpha(Colors.surfaceContainerHighest, 0.85)
            KitText {
                anchors.left: parent.left
                anchors.leftMargin: Math.round(stage.u * 0.5)
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                font.pixelSize: Math.round(stage.fs * 0.9)
                color: Type.muted
                text: I18n.t("prefs.voice.stage.ask")
            }
            Mark {
                anchors.right: parent.right
                anchors.rightMargin: Math.round(stage.u * 0.25)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(stage.u * 1.1)
                height: width
                color: Type.accent
                Icon {
                    anchors.centerIn: parent
                    icon: Icons.paperPlaneRight
                    size: Math.round(stage.u * 0.6)
                    tone: "accentInk"
                }
            }
        }
    }
    StageSpot {
        anchors.fill: panel
        keys: ["ai.appearance.defaultSize", "ai.sidebarPosition", "ai.enabled"]
        cornerRadius: panel.radius
    }

    // a click on the other edge moves it there

    component Pill: Mark {
        id: pill
        property string icon: ""
        property string text: ""
        property bool accent: false
        // off: a dashed outline with the icon only
        property bool ghost: false
        width: pillRow.implicitWidth + stage.u * 0.6
        height: Math.round(stage.u * 1.05)
        radius: Look.radius("chip", height)
        color: pill.ghost ? "transparent" : (pill.accent ? Qt.alpha(Type.accent, 0.16) : Qt.alpha(Type.text, 0.06))
        border.width: pill.ghost ? 0 : Space.hairline
        border.color: pill.accent ? Qt.alpha(Type.accent, 0.5) : Type.hairline
        DashedFrame {
            visible: pill.ghost
            anchors.fill: parent
            radius: pill.radius
            color: Qt.alpha(Type.muted, 0.8)
        }
        Row {
            id: pillRow
            anchors.centerIn: parent
            opacity: pill.ghost ? 0.6 : 1
            spacing: Math.round(stage.u * 0.2)
            Icon {
                visible: pill.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                icon: pill.icon
                size: Math.round(stage.u * 0.5)
                tone: pill.accent ? "accent" : "secondary"
            }
            KitText {
                anchors.verticalCenter: parent.verticalCenter
                visible: pill.text !== ""
                role: "caption"
                font.pixelSize: Math.round(stage.u * 0.46)
                color: pill.accent ? Type.accent : Type.secondary
                text: pill.text
            }
        }
    }

    // One message: yours on the right (a filled bubble, or flat text with
    // your name), the answer on the left (with its avatar when shown).
    component Message: Item {
        id: msg
        property bool mine: false
        property string text: ""
        property string time: ""
        readonly property real room: chat.width - (msg.mine || !stage.avatars ? 0 : avatar.width + Math.round(stage.u * 0.4)) - (msg.mine && stage.bubbles ? chat.width * 0.18 : 0)
        width: chat.width
        height: Math.max(avatar.visible ? avatar.height : 0, box.height + (stamp.visible ? stamp.height + Math.round(stage.u * 0.1) : 0))

        Mark {
            id: avatar
            visible: !msg.mine && stage.avatars
            width: Math.round(stage.u * 1.1)
            height: width
            color: Type.accent
            Icon {
                anchors.centerIn: parent
                icon: Icons.sparkle
                size: Math.round(stage.u * 0.6)
                tone: "accentInk"
            }
        }
        Mark {
            id: box
            readonly property bool filled: stage.bubbles
            x: msg.mine ? (stage.bubbles ? msg.width - width : 0) : (avatar.visible ? avatar.width + Math.round(stage.u * 0.4) : 0)
            width: filled ? Math.min(msg.room, body.implicitWidth + stage.u * 1.0) : msg.room
            height: body.height + (filled ? stage.u * 0.6 : 0)
            radius: Look.radius("box", Math.min(height, stage.u * 2))
            color: !filled ? "transparent" : (msg.mine ? Qt.alpha(Type.accent, 0.22) : Qt.alpha(Type.text, 0.07))
            KitText {
                id: body
                x: box.filled ? Math.round(stage.u * 0.5) : 0
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, msg.room - (box.filled ? stage.u : 0))
                role: "body"
                font.pixelSize: stage.fs
                font.weight: !box.filled && msg.mine ? Font.Medium : Font.Normal
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                text: msg.text
            }
        }
        KitText {
            id: stamp
            visible: stage.times
            anchors.top: box.bottom
            anchors.topMargin: Math.round(stage.u * 0.1)
            x: msg.mine && stage.bubbles ? msg.width - width : box.x
            role: "caption"
            font.pixelSize: Math.round(stage.fs * 0.75)
            color: Type.muted
            text: msg.time
        }
    }
}
