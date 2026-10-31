import QtQuick
import qs.config
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.controls
import qs.modules.bar.sentence
import "../../bar/sentence/Sentence.js" as Sentence

// The sentence bar module as it reads now with the current
// bar.moduleOptions.sentence (fragments, separator, verbosity, typeface,
// width): the same SentenceData + SentenceLine, not clickable.
PreviewStage {
    id: root

    property var entry
    readonly property var options: Config.bar.moduleOptions && Config.bar.moduleOptions.sentence ? Config.bar.moduleOptions.sentence : ({})
    readonly property bool editorial: root.options.typeface !== "body"
    readonly property int bodySize: Type.size("body")

    stageHeight: Space.rowHeight * 2

    SentenceData {
        id: facts
        order: Sentence.normalizeList(root.options.fragments, Sentence.DEFAULT_ORDER)
        verbosity: Sentence.verbosity(root.options.verbosity)
        active: root.visible
    }

    SentenceLine {
        id: line
        objectName: "sentencePreviewLine"
        anchors.centerIn: parent
        visible: facts.fragments.length > 0
        interactive: false
        fragments: facts.fragments
        priority: Sentence.normalizePriority(root.options.priority)
        budget: Math.min(root.width - Space.l * 2, root.options.maxWidth > 0 ? root.options.maxWidth : Infinity)
        separator: Sentence.separator(root.options.separator)
        textFont: root.editorial ? Type.family("editorial") : Type.bodyFont
        textSize: root.editorial ? Math.round(root.bodySize * Type.scale.editorial) : root.bodySize
        textWeight: root.editorial ? Type.weight("editorial") : Type.weight("body")
        ink: Type.text
    }

    KitText {
        anchors.centerIn: parent
        visible: !line.visible
        role: "caption"
        text: I18n.t("prefs.bar.sentence.empty")
    }
}
