pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// `· high ▾` next to the engine chip: the reasoning effort of the visible
// engine, changed in place with a segmented selector. Hidden when the model
// has no effort control (Ai.effort.levels is empty). The choice becomes the
// model's default (EffortState).
StyledRect {
    id: root
    objectName: "composerEffort"

    readonly property var levels: Ai.effort ? Ai.effort.levels : []
    readonly property string level: Ai.effort ? Ai.effort.level : ""
    // "" (auto) first: the engine's own default.
    readonly property var options: levels.length > 0 ? [""].concat(levels) : []

    function label(l) {
        if (!l)
            return Ai.effort && Ai.effort.autoHint ? I18n.t("ai.effort_level.auto") + " (" + label(Ai.effort.autoHint) + ")" : I18n.t("ai.effort_level.auto");
        const key = "ai.effort_level." + l;
        const t = I18n.t(key);
        return t === key ? l : t;
    }

    visible: Config.ai.strip.effort !== false && levels.length > 0
    implicitWidth: row.implicitWidth + 2 * Space.s
    implicitHeight: row.implicitHeight + 2 * Space.xs
    radius: Look.radius("control")
    variant: hover.hovered || popup.opened ? "common" : "transparent"

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: {
            if (Ai.effort)
                Ai.effort.ensureAgentCatalog();
            popup.open();
        }
    }
    StyledToolTip {
        tooltipText: I18n.t("ai.effort")
        desciription: I18n.t("ai.effort_tip")
        show: hover.hovered && !popup.opened
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Space.xs
        Icon {
            role: "caption"
            icon: Icons.brain
            size: BarLook.size("caption")
            color: root.level && root.level !== "off" && root.level !== "none" ? Colors.primary : Colors.outline
        }
        // The level a turn will use: chosen, else the engine's own default
        // (outlined brain = auto); the popup spells out "Auto (medium)".
        AiText {
            objectName: "composerEffortLabel"
            role: "caption"
            text: !root.level && Ai.effort && Ai.effort.autoHint ? root.label(Ai.effort.autoHint) : root.label(root.level)
            color: Type.secondary
        }
        Icon {
            role: "caption"
            tone: "muted"
            icon: Icons.caretDown
            size: BarLook.size("caption")
        }
    }

    Popup {
        id: popup
        objectName: "effortSelector"
        y: -height - Space.s
        // Kept inside the window in the compact bar.
        margins: Space.s
        padding: Space.s
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: StyledRect {
            variant: "popup"
            radius: Look.radius("control")
            enableShadow: true
        }
        contentItem: ColumnLayout {
            spacing: Space.s
            AiText {
                role: "caption"
                Layout.leftMargin: Space.xs
                text: I18n.t("ai.effort")
                font.weight: Font.DemiBold
            }
            StyledRect {
                variant: "internalbg"
                radius: Look.radius("control")
                implicitWidth: segments.implicitWidth + 2 * Space.xs
                implicitHeight: segments.implicitHeight + 2 * Space.xs
                RowLayout {
                    id: segments
                    anchors.centerIn: parent
                    spacing: Space.xs / 2
                    Repeater {
                        model: root.options
                        delegate: StyledRect {
                            id: seg
                            required property string modelData
                            readonly property bool current: modelData === root.level
                            objectName: "effortOption_" + (modelData || "auto")
                            implicitWidth: Math.max(48, segLabel.implicitWidth + 2 * Space.s)
                            implicitHeight: segLabel.implicitHeight + 2 * Space.xs
                            radius: Look.radius("small")
                            variant: current ? "primary" : (segHover.hovered ? "focus" : "transparent")
                            opacity: Ai.busy && !current ? 0.5 : 1
                            Behavior on opacity {
                                enabled: BarLook.animDuration > 0
                                NumberAnimation {
                                    duration: BarLook.animDuration / 3
                                }
                            }
                            HoverHandler {
                                id: segHover
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: {
                                    if (Ai.effort && Ai.effort.set(seg.modelData))
                                        popup.close();
                                }
                            }
                            AiText {
                                id: segLabel
                                role: "caption"
                                anchors.centerIn: parent
                                text: seg.modelData ? root.label(seg.modelData) : I18n.t("ai.effort_level.auto")
                                font.weight: seg.current ? Font.DemiBold : Font.Normal
                                color: seg.current ? Styling.srItem("primary") : Colors.overSurface
                            }
                        }
                    }
                }
            }
            AiText {
                role: "caption"
                Layout.leftMargin: Space.xs
                Layout.maximumWidth: segments.implicitWidth
                text: Ai.busy ? I18n.t("ai.settings_busy") : I18n.t("ai.effort_remembered")
                wrapMode: Text.Wrap
            }
        }
    }
}
