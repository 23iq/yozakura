pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit

// Stage of Look > Icons & type: a type specimen on the theme's popup
// surface over your wallpaper, set in the shell's own text roles: the
// heading (its font and letter case), body text in the UI font and size,
// a line of code in the mono font, an editorial line, and a row of shell
// icons in the chosen weight. Rows light up the line they change.
Stage {
    id: stage

    stageHeight: Space.px(300)

    Surface {
        id: sheet
        anchors.centerIn: parent
        width: Math.min(stage.width - Space.xxl * 2, Space.px(620))
        enableShadow: true

        ColumnLayout {
            width: sheet.width - sheet.padding * 2
            spacing: Space.m

            RowLayout {
                Layout.fillWidth: true
                spacing: Space.l
                KitText {
                    Layout.fillWidth: true
                    role: "title"
                    text: I18n.t("prefs.look.stage.heading")
                    StageSpot {
                        keys: ["theme.type.heading", "theme.type.headingCase"]
                    }
                }
                Item {
                    implicitWidth: glyphs.implicitWidth
                    implicitHeight: glyphs.implicitHeight
                    Row {
                        id: glyphs
                        spacing: Space.m
                        Repeater {
                            model: ["wifiHigh", "bell", "speakerHigh", "batteryHigh"]
                            delegate: Icon {
                                required property string modelData
                                required property int index
                                icon: Icons[modelData] ?? ""
                                role: "title"
                                tone: index === 1 ? "accent" : "text"
                            }
                        }
                    }
                    StageSpot {
                        keys: ["theme.icons"]
                    }
                }
            }
            KitText {
                Layout.fillWidth: true
                role: "body"
                wrapMode: Text.WordWrap
                text: I18n.t("prefs.look.stage.body")
                StageSpot {
                    keys: ["theme.font", "theme.fontSize"]
                }
            }
            KitText {
                Layout.fillWidth: true
                role: "editorial"
                wrapMode: Text.WordWrap
                text: I18n.t("prefs.look.stage.editorial")
                StageSpot {
                    keys: ["theme.type.editorial"]
                }
            }
            KitText {
                Layout.fillWidth: true
                role: "secondary"
                font.family: Type.monoFont
                color: Type.accent
                text: "yozakura config set theme.roundness 16"
                elide: Text.ElideRight
                StageSpot {
                    keys: ["theme.monoFont", "theme.monoFontSize"]
                }
            }
        }
    }
}
