pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.live

// Stage of Chat: the Assistant's real panel (modules/aicenter/
// AiCenterPreview: AiCenterPanel's header, conversation, status strip and
// composer, by URL) on its side of the screen at its size, holding a short
// sample conversation (a question, the thinking, a tool call and the
// answer). Everything it shows follows the live options by itself: the
// message style, density, text size, avatars and times, the thinking
// line, the strip items, your model. Off, the panel is a faint ghost. The
// stage's top edge cuts the panel: its end (the answer and the field) is
// what shows.
Stage {
    id: stage
    objectName: "assistantStage"

    readonly property bool on: SettingsStore.get("ai.enabled") !== false
    readonly property string side: SettingsStore.get("ai.sidebarPosition") === "left" ? "left" : "right"
    readonly property string size: String(SettingsStore.get("ai.appearance.defaultSize") || "compact") === "compact" ? "compact" : "wide"
    // the default model by its id ("provider:model"), without waking the
    // AI service
    readonly property string modelId: String(SettingsStore.get("ai.defaultModel") || "")
    // (none chosen: the strip asks for one, as the panel does)
    readonly property var model: stage.modelId ? {
        "name": stage.modelId.slice(stage.modelId.indexOf(":") + 1),
        "provider": stage.modelId.slice(0, Math.max(0, stage.modelId.indexOf(":"))),
        "kind": "chat"
    } : null
    // a fixed moment, so the picture never changes by itself
    readonly property real at: new Date(2026, 0, 1, 21, 46).getTime()

    // a strip as wide as the page (SettingsPage)
    readonly property bool pageWide: true
    readonly property real preferredHeight: Space.px(250)

    stageHeight: stage.preferredHeight

    LiveHosted {
        id: panel
        objectName: "assistantPanel"
        anchors.fill: parent
        host: "sidebar"
        side: stage.side
        source: Qt.resolvedUrl("../../aicenter/AiCenterPreview.qml")
        minZoom: 0.62
        maxZoom: 0.8
        opacity: stage.on ? 1 : 0.35
        samples: ({
                "ai.size": stage.size,
                "ai.model": stage.model,
                "ai.effortLevels": ["low", "medium", "high"],
                "ai.effort": "high",
                "ai.cost": "$0.04",
                "ai.context": [24000, 200000],
                "ai.rows": [
                    {
                        "role": "user",
                        "content": I18n.t("prefs.ai.stage.ask"),
                        "ts": stage.at
                    },
                    {
                        "role": "assistant",
                        "thinking": I18n.t("prefs.ai.stage.thinking"),
                        "toolCalls": JSON.stringify([
                            {
                                "id": "sample-1",
                                "tool": "config_set",
                                "title": I18n.t("prefs.ai.stage.tool"),
                                "category": "config",
                                "args": {
                                    "key": "bar.style",
                                    "value": "floating"
                                },
                                "status": "done",
                                "result": "ok"
                            }
                        ]),
                        "content": I18n.t("prefs.ai.stage.answer"),
                        "model": stage.model ? stage.model.name : "",
                        "status": "done",
                        "ts": stage.at + 60000
                    }
                ]
            })
    }

    ViewSpot {
        hosted: panel
        name: "workspaceChatList"
        keys: ["ai.appearance.messageStyle", "ai.appearance.density", "ai.appearance.fontScale", "ai.appearance.showAvatars", "ai.appearance.showTimestamps", "ai.showThinking"]
    }
    ViewSpot {
        hosted: panel
        name: "composerEngine"
        keys: ["ai.strip", "ai.defaultModel"]
    }
    StageSpot {
        anchors.fill: undefined
        x: panel.frameRect.x - spread
        y: panel.frameRect.y - spread
        width: panel.frameRect.width + spread * 2
        height: panel.frameRect.height + spread * 2
        keys: ["ai.appearance.defaultSize", "ai.sidebarPosition", "ai.enabled", "ai.appearance.glass"]
    }
}
