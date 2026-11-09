import QtQuick
import qs.modules.components.kit

// Japanese numerals: 十時 二十五分 (12h: 午後 一時 三十分). The theme font
// falls back to the system CJK font for the glyphs. A vertical bar sets the
// characters top to bottom, one per line, like vertical Japanese text.
KitText {
    id: root

    required property var clock

    objectName: "faceKanji"
    elide: Text.ElideNone
    text: clock.vertical ? Array.from(clock.kanji.replace(/ /g, "")).join("\n") : clock.kanji
    horizontalAlignment: Text.AlignHCenter
    color: clock.textColor
    font.family: clock.fontFamily
    font.pixelSize: clock.fontSize
    font.weight: clock.fontWeight
    lineHeight: 0.95
}
