pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
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
    implicitWidth: row.implicitWidth + 14
    implicitHeight: row.implicitHeight + 8
    radius: Styling.radius(-4)
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
        spacing: 5
        Text {
            text: Icons.brain
            font.family: Icons.font
            font.pixelSize: BarLook.font(-3)
            color: root.level && root.level !== "off" && root.level !== "none" ? Colors.primary : Colors.outline
        }
        // The level a turn will use: chosen, else the engine's own default
        // (outlined brain = auto); the popup spells out "Auto (medium)".
        Text {
            objectName: "composerEffortLabel"
            text: !root.level && Ai.effort && Ai.effort.autoHint ? root.label(Ai.effort.autoHint) : root.label(root.level)
            font.family: Config.theme.font
            font.pixelSize: BarLook.font(-3)
            color: Colors.overSurfaceVariant
        }
        Text {
            text: Icons.caretDown
            font.family: Icons.font
            font.pixelSize: BarLook.font(-5)
            color: Colors.outline
        }
    }

    Popup {
        id: popup
        objectName: "effortSelector"
        y: -height - 6
        // Kept inside the window in the compact bar.
        margins: 8
        padding: 6
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: StyledRect {
            variant: "popup"
            radius: Styling.radius(-2)
            enableShadow: true
        }
        contentItem: ColumnLayout {
            spacing: 6
            Text {
                Layout.leftMargin: 4
                text: I18n.t("ai.effort")
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-4)
                font.weight: Font.DemiBold
                color: Colors.outline
            }
            StyledRect {
                variant: "internalbg"
                radius: Styling.radius(-4)
                implicitWidth: segments.implicitWidth + 6
                implicitHeight: segments.implicitHeight + 6
                RowLayout {
                    id: segments
                    anchors.centerIn: parent
                    spacing: 2
                    Repeater {
                        model: root.options
                        delegate: StyledRect {
                            id: seg
                            required property string modelData
                            readonly property bool current: modelData === root.level
                            objectName: "effortOption_" + (modelData || "auto")
                            implicitWidth: Math.max(48, segLabel.implicitWidth + 18)
                            implicitHeight: segLabel.implicitHeight + 10
                            radius: Styling.radius(-6)
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
                            Text {
                                id: segLabel
                                anchors.centerIn: parent
                                text: seg.modelData ? root.label(seg.modelData) : I18n.t("ai.effort_level.auto")
                                font.family: Config.theme.font
                                font.pixelSize: BarLook.font(-3)
                                font.weight: seg.current ? Font.DemiBold : Font.Normal
                                color: seg.current ? Styling.srItem("primary") : Colors.overSurface
                            }
                        }
                    }
                }
            }
            Text {
                Layout.leftMargin: 4
                Layout.maximumWidth: segments.implicitWidth
                text: Ai.busy ? I18n.t("ai.settings_busy") : I18n.t("ai.effort_remembered")
                wrapMode: Text.Wrap
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-5)
                color: Colors.outline
            }
        }
    }
}
