pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Stage of Fonts & icons: a type specimen in your fonts, live. A heading
// in the heading font and case, a paragraph in the interface font at its
// size, a line of code in the code font at its size and a quote in the
// editorial face; each named over its sample (font and size), so the rows
// beside it read as what they do. A plain stage (the card fill): the type
// is the subject, not the desktop.
Stage {
    id: stage
    objectName: "typeStage"

    readonly property string uiFont: String(SettingsStore.get("theme.font") || Type.bodyFont)
    readonly property int uiSize: Number(SettingsStore.get("theme.fontSize")) || Type.base
    readonly property string monoFont: String(SettingsStore.get("theme.monoFont") || Type.monoFont)
    readonly property int monoSize: Number(SettingsStore.get("theme.monoFontSize")) || Type.base
    readonly property string headingName: String(SettingsStore.get("theme.type.heading") || "")
    readonly property string editorialName: String(SettingsStore.get("theme.type.editorial") || "")
    readonly property real pad: Space.xl
    // as tall as the specimen asks (never cut)
    readonly property real preferredHeight: Math.round(sheet.implicitHeight + stage.pad * 2)

    stageHeight: Space.px(300)

    // "<what> · <font> · <size> px": the caption over a sample
    function caption(labelKey, font, size) {
        return [I18n.t(labelKey), font].concat(size > 0 ? [size + " px"] : []).join("  ·  ");
    }

    Column {
        id: sheet
        objectName: "typeSpecimen"
        x: stage.pad
        y: stage.pad
        width: stage.width - stage.pad * 2
        spacing: Space.l

        // Heading: the heading font, in the heading case
        Item {
            width: parent.width
            height: headingBlock.implicitHeight
            Column {
                id: headingBlock
                width: parent.width
                spacing: Space.xs
                KitText {
                    width: parent.width
                    role: "caption"
                    text: stage.caption("prefs.icons_type.heading_font", stage.headingName !== "" ? stage.headingName : I18n.t("prefs.icons_type.heading_font.placeholder"), 0)
                }
                KitText {
                    objectName: "specimenHeading"
                    width: parent.width
                    role: "title"
                    font.pixelSize: Math.round(Type.size("title") * 1.7)
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    text: I18n.t("prefs.icons_type.specimen.heading")
                }
            }
            StageSpot {
                anchors.fill: parent
                keys: ["theme.type.heading", "theme.type.headingCase"]
                spread: Space.s
            }
        }

        // Text: the interface font at its size
        Item {
            width: parent.width
            height: bodyBlock.implicitHeight
            Column {
                id: bodyBlock
                width: parent.width
                spacing: Space.xs
                KitText {
                    width: parent.width
                    role: "caption"
                    text: stage.caption("settings.theme.ui_font", stage.uiFont, stage.uiSize)
                }
                KitText {
                    objectName: "specimenBody"
                    width: parent.width
                    role: "body"
                    wrapMode: Text.WordWrap
                    maximumLineCount: 4
                    lineHeight: 1.15
                    text: I18n.t("prefs.icons_type.specimen.body")
                }
            }
            StageSpot {
                anchors.fill: parent
                keys: ["theme.font", "theme.fontSize"]
                spread: Space.s
            }
        }

        // Code: the code font at its size, on a quiet well
        Item {
            width: parent.width
            height: codeBlock.implicitHeight
            Column {
                id: codeBlock
                width: parent.width
                spacing: Space.xs
                KitText {
                    width: parent.width
                    role: "caption"
                    text: stage.caption("settings.theme.mono_font", stage.monoFont, stage.monoSize)
                }
                Well {
                    width: parent.width
                    height: code.implicitHeight + Space.m * 2
                    radius: Look.radius("small", height)
                    KitText {
                        id: code
                        objectName: "specimenCode"
                        x: Space.m
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Space.m * 2
                        role: "body"
                        font.family: stage.monoFont
                        font.pixelSize: stage.monoSize
                        // glyphs a code face must tell apart, then a line of code
                        text: "0O lI1 {} [] => != ===\nlet size = " + stage.monoSize + "; // px"
                        maximumLineCount: 2
                    }
                }
            }
            StageSpot {
                anchors.fill: parent
                keys: ["theme.monoFont", "theme.monoFontSize"]
                spread: Space.s
            }
        }

        // Prose: the editorial face (the sentence bar)
        Item {
            width: parent.width
            height: proseBlock.implicitHeight
            Column {
                id: proseBlock
                width: parent.width
                spacing: Space.xs
                KitText {
                    width: parent.width
                    role: "caption"
                    text: stage.caption("prefs.icons_type.editorial_font", stage.editorialName !== "" ? stage.editorialName : I18n.t("prefs.icons_type.editorial_font.placeholder"), 0)
                }
                KitText {
                    objectName: "specimenProse"
                    width: parent.width
                    role: "editorial"
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    text: I18n.t("prefs.icons_type.specimen.prose")
                }
            }
            StageSpot {
                anchors.fill: parent
                keys: ["theme.type.editorial"]
                spread: Space.s
            }
        }
    }
}
