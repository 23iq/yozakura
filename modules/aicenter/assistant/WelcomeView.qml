pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.components.kit
import "Suggestions.js" as Suggestions
import "../../services/ai/EngineSelection.js" as Selection

// Assistant empty state: greeting, contextual suggestion chips
// (Suggestions.js over Ai.ambientContext()) and recent chats. Without any
// usable model it shows one "Connect a model" call to action instead.
Item {
    id: root
    objectName: "welcomeView"

    property int maxSuggestions: 4
    signal suggestion(string text, string context)
    signal connectRequested

    readonly property bool noModels: !(Ai.models || []).some(m => m.available !== false)
    readonly property string userName: {
        const u = Quickshell.env("USER") || "";
        return u ? u.charAt(0).toUpperCase() + u.slice(1) : "";
    }
    readonly property string greeting: {
        const h = new Date().getHours();
        return I18n.t(h < 5 ? "ai.greet_night" : (h < 12 ? "ai.greet_morning" : (h < 18 ? "ai.greet_afternoon" : "ai.greet_evening")));
    }
    property var ambient: ({})
    readonly property var suggestions: BarLook.behavior.suggestions === false ? [] : Suggestions.suggest(ambient, BarLook.behavior.suggestionKinds || [], maxSuggestions)
    readonly property var recent: Selection.sessions(Ai.store ? Ai.store.chats : [], Ai.drafts ? Ai.drafts.summaries : [], Ai.agents ? Ai.agents.sessions : [], "", "assistant").filter(e => e.id !== (Ai.activeChat ? Ai.activeChat.chatId : "") && (e.title || e.lastText)).slice(0, 3)

    function refresh() {
        ambient = Ai.ambientContext ? Ai.ambientContext() : ({});
    }
    Component.onCompleted: refresh()
    onVisibleChanged: if (visible)
        refresh()

    function label(s) {
        let t = I18n.t(s.text);
        for (let i = 0; i < (s.args || []).length; i++)
            t = t.replace("%" + (i + 1), s.args[i]);
        return t;
    }

    CenteredScroll {
        anchors.fill: parent
        maxContentWidth: 560
        spacing: BarLook.groupGap

        ColumnLayout {
            Layout.fillWidth: true
            spacing: BarLook.gap
            Icon {
                role: "title"
                tone: "secondary"
                Layout.alignment: Qt.AlignHCenter
                icon: Icons.sparkle
                size: BarLook.size("title")
            }
            AiText {
                role: "title"
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.greeting + (root.userName ? ", " + root.userName : "")
                font.weight: Font.Bold
            }
            AiText {
                role: "secondary"
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.noModels ? I18n.t("ai.connect_hint") : I18n.t("ai.assistant_hint")
                color: Type.muted
            }
            UsingModel {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.width
                visible: !root.noModels
            }
        }

        // The one primary action when nothing can answer yet.
        Chip {
            objectName: "connectModel"
            visible: root.noModels
            Layout.alignment: Qt.AlignHCenter
            primary: true
            icon: Icons.plug
            text: I18n.t("ai.connect_model")
            onClicked: root.connectRequested()
        }

        CenteredFlow {
            objectName: "suggestionChips"
            visible: !root.noModels && root.suggestions.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            spacing: Space.s
            Repeater {
                model: root.noModels ? [] : root.suggestions
                delegate: Chip {
                    id: chip
                    required property var modelData
                    icon: Icons[chip.modelData.icon] || Icons.sparkle
                    text: root.label(chip.modelData)
                    maxLabelWidth: 300
                    onClicked: root.suggestion(root.label(chip.modelData), chip.modelData.context)
                }
            }
        }

        ColumnLayout {
            visible: !root.noModels && root.recent.length > 0
            Layout.fillWidth: true
            spacing: Space.xs / 2
            AiText {
                role: "caption"
                Layout.leftMargin: Space.xs
                text: I18n.t("ai.recent_chats")
                font.weight: Font.DemiBold
            }
            Repeater {
                model: root.recent
                delegate: StyledRect {
                    id: recentRow
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: Space.controlS
                    radius: Look.radius("control")
                    variant: recentHover.hovered ? "common" : "transparent"
                    HoverHandler {
                        id: recentHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: Ai.openConversation(recentRow.modelData.kind, recentRow.modelData.id)
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Space.s
                        anchors.rightMargin: Space.s
                        spacing: Space.s
                        Icon {
                            role: "caption"
                            tone: "muted"
                            icon: recentRow.modelData.kind === "agent" ? Icons.terminalWindow : Icons.chatTeardrop
                            size: BarLook.size("caption")
                        }
                        AiText {
                            role: "secondary"
                            Layout.fillWidth: true
                            text: recentRow.modelData.title || recentRow.modelData.lastText || I18n.t("ai.untitled")
                            elide: Text.ElideRight
                            color: Type.text
                        }
                    }
                }
            }
        }
    }
}
