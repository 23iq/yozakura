pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.aicenter.providers
import "../../services/ai/ProviderConnect.js" as Connect

// Band of AI providers (list form): where answers come from (the default
// model and its provider) and every provider as its logo in its state:
// ready (accent ring), needs a key or not running (faint), hidden from
// the picker (struck through), with the counts. Keys never show here.
Stage {
    id: band

    readonly property var presets: Connect.presets()
    readonly property var providerStates: {
        // re-evaluated when keys, probes or the hidden list change
        const deps = [Ai.providers.connectionState, Ai.providers.hidden];
        return band.presets.map(p => Ai.providers.status(p.id) || ({}));
    }
    readonly property int ready: band.providerStates.filter(s => s.connected === true).length
    readonly property int hidden: band.providerStates.filter(s => s.state === "hidden").length
    readonly property int waiting: band.presets.length - band.ready - band.hidden
    readonly property string modelId: String(SettingsStore.get("ai.defaultModel") || "")
    readonly property var modelPreset: band.presets.find(p => band.modelId.indexOf(p.id + ":") === 0) || null
    readonly property real u: Math.max(Space.px(10), Math.min(band.height * 0.1, band.width * 0.016))

    stageHeight: Space.px(170)

    // where answers come from
    Row {
        id: source
        objectName: "providersSource"
        x: Math.round(band.u * 2)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(band.width * 0.34)
        spacing: Math.round(band.u * 1.2)
        Mark {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(band.u * 4.4)
            height: width
            radius: Look.radius("box", height)
            color: Type.accent
            ProviderIcon {
                anchors.centerIn: parent
                visible: band.modelPreset !== null
                icon: band.modelPreset ? band.modelPreset.icon || "" : ""
                size: Math.round(band.u * 2.4)
                color: Type.accentInk
            }
            Icon {
                anchors.centerIn: parent
                visible: band.modelPreset === null
                icon: Icons.sparkle
                size: Math.round(band.u * 2.2)
                tone: "accentInk"
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: source.width - band.u * 5.6
            spacing: Math.round(band.u * 0.2)
            KitText {
                width: parent.width
                role: "caption"
                color: Type.muted
                text: I18n.t("prefs.ai.providers.band.source")
            }
            KitText {
                width: parent.width
                role: "title"
                // a long name wraps onto a second line, whole
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideNone
                text: band.modelId ? band.modelId.slice(band.modelId.indexOf(":") + 1) : I18n.t("prefs.ai.default_engine.last")
            }
            KitText {
                width: parent.width
                visible: band.modelPreset !== null
                role: "secondary"
                elide: Text.ElideRight
                text: band.modelPreset ? band.modelPreset.label : ""
            }
        }
    }
    StageSpot {
        anchors.fill: source
        anchors.margins: -Space.s
        keys: ["ai.defaultModel"]
    }

    // every provider in its state
    Column {
        id: all
        anchors.right: parent.right
        anchors.rightMargin: Math.round(band.u * 2)
        anchors.verticalCenter: parent.verticalCenter
        width: band.width - source.width - band.u * 6
        spacing: Math.round(band.u * 0.9)

        Flow {
            width: parent.width
            spacing: Math.round(band.u * 0.6)
            Repeater {
                model: band.presets
                delegate: Mark {
                    id: logo
                    required property var modelData
                    required property int index
                    readonly property var st: band.providerStates[logo.index] || ({})
                    readonly property bool on: logo.st.connected === true
                    readonly property bool off: logo.st.state === "hidden"
                    objectName: "providerState:" + logo.modelData.id
                    width: Math.round(band.u * 2.7)
                    height: width
                    color: logo.on ? Qt.alpha(Type.accent, 0.16) : Qt.alpha(Colors.surfaceContainer, 0.85)
                    border.width: logo.on ? Math.max(2, Math.round(band.u * 0.16)) : Space.hairline
                    border.color: logo.on ? Type.accent : Qt.alpha(Colors.outlineVariant, 0.8)
                    opacity: logo.off ? 0.35 : (logo.on ? 1 : 0.7)
                    ProviderIcon {
                        anchors.centerIn: parent
                        icon: logo.modelData.icon || ""
                        size: Math.round(band.u * 1.4)
                        color: logo.on ? Type.accent : Type.secondary
                    }
                    // hidden from the picker: struck through
                    Mark {
                        visible: logo.off
                        anchors.centerIn: parent
                        width: parent.width * 0.9
                        height: Math.max(2, Math.round(band.u * 0.14))
                        rotation: -45
                        color: Type.muted
                    }
                }
            }
        }
        Row {
            spacing: Math.round(band.u * 1.2)
            Count {
                dot: Type.accent
                text: I18n.tn("prefs.ai.providers.band.ready", band.ready)
            }
            Count {
                dot: Qt.alpha(Type.secondary, 0.6)
                text: I18n.tn("prefs.ai.providers.band.waiting", band.waiting)
            }
            Count {
                visible: band.hidden > 0
                dot: Qt.alpha(Type.muted, 0.5)
                text: I18n.tn("prefs.ai.providers.band.hidden", band.hidden)
            }
        }
    }
    StageSpot {
        anchors.fill: all
        anchors.margins: -Space.s
        keys: ["ai.providers"]
    }

    // a count with its colour dot
    component Count: Row {
        id: count
        property color dot: Type.accent
        property string text: ""
        spacing: Math.round(band.u * 0.4)
        Mark {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(band.u * 0.7)
            height: width
            color: count.dot
        }
        KitText {
            anchors.verticalCenter: parent.verticalCenter
            role: "secondary"
            color: Type.text
            text: count.text
        }
    }
}
