pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.store
import qs.modules.components.kit
import "TermModel.js" as TermModel
import "FetchModel.js" as FetchModel

// Settings > Terminal > When a terminal opens: the fastfetch greeting
// (terminal.greeting, independent of the prompt) with a live preview of
// what fastfetch prints in this look, the look chips, the logo chips and
// the logo file. fastfetch missing: a bundled sample and an install action
// (the switch turning on queues it too). Writes go through SettingsStore;
// the backend writes the files (term.apply, TerminalLookService).
Column {
    id: root

    property bool animate: true

    readonly property var term: Config.terminal
    readonly property bool on: !!root.term && root.term.greeting === "fastfetch"
    readonly property string preset: root.term ? String(root.term.fastfetchPreset || "own") : "own"
    readonly property string logo: root.term ? String(root.term.fastfetchLogo || "sakura") : "sakura"
    readonly property string logoPath: root.term ? String(root.term.fastfetchLogoPath || "") : ""
    readonly property var presetInfo: FetchModel.presetOf(TerminalLookService.fetchPresets, root.preset)
    readonly property string logoBlocked: FetchModel.logoBlocked(root.presetInfo)
    readonly property var preview: TerminalLookService.fetchPreviews[FetchModel.previewKey(root.preset, root.logo, root.logoPath)]
    readonly property string sample: FetchModel.sampleReason(root.preview)
    readonly property var greeting: TerminalLookService.greeting
    readonly property bool installing: ExtrasService.cardState("fastfetch") === "installing"
    readonly property bool installable: ExtrasService.cardState("fastfetch") === "selectable"
    readonly property var shells: FetchModel.shellsOn(root.greeting)
    readonly property string home: Quickshell.env("HOME") || ""
    // The prompt above when it is on, else a plain one.
    readonly property var promptPreview: root.term && root.term.enabled ? TerminalLookService.previews[TermModel.previewKey(TerminalLookService.engine, TerminalLookService.prompt)] : ({
            "left": [[
                    {
                        "text": "~",
                        "fg": String(Colors.primary)
                    },
                    {
                        "text": " $ "
                    }
                ]],
            "right": []
        })

    spacing: Space.m

    function _ensure() {
        TerminalLookService.ensureFetch(root.preset, root.logo, root.logoPath);
    }
    onPresetChanged: root._ensure()
    onLogoChanged: root._ensure()
    onLogoPathChanged: root._ensure()
    Component.onCompleted: {
        TerminalLookService.load();
        root._ensure();
    }

    // On: a look that does something (own needs a fastfetch config of the
    // user's) and fastfetch queued when it is missing.
    function setOn(v) {
        if (!v) {
            SettingsStore.set("terminal.greeting", "none");
            return;
        }
        const look = FetchModel.presetOnTurnOn(root.preset, !!(root.greeting && root.greeting.ownConfig));
        if (look !== root.preset)
            SettingsStore.set("terminal.fastfetchPreset", look);
        SettingsStore.set("terminal.greeting", "fastfetch");
        if (!TerminalLookService.fastfetchInstalled)
            TerminalLookService.installFastfetch();
    }

    ListRow {
        objectName: "fetchSwitchRow"
        width: root.width
        title: I18n.t("prefs.term.fetch.on")
        subtitle: !root.on ? I18n.t("prefs.term.fetch.off") : (root.shells.length > 0 ? I18n.t("prefs.term.fetch.where", root.shells.join(", ")) : I18n.t("prefs.term.fetch.where_none"))
        onClicked: root.setOn(!root.on)
        trailing: Component {
            Switch {
                objectName: "fetchSwitch"
                checked: root.on
                onToggled: v => root.setOn(v)
            }
        }
    }

    TerminalPreview {
        objectName: "fetchPreview"
        width: root.width
        opacity: root.on ? 1 : 0.55
        preview: root.promptPreview
        greeting: true
        greetingLines: root.preview && root.preview.lines && root.preview.lines.length > 0 ? root.preview.lines : null
        showSession: false
        fontFamily: TerminalLookService.fontFamily
        pixelSize: TerminalLookService.fontPixelSize
        padding: root.term ? Number(root.term.padding) : Space.m
        cursorShape: root.term ? root.term.cursorShape : "beam"
        cursorBlink: root.term ? root.term.cursorBlink : true
        backgroundOpacity: Glass.terminalOpacity
        animate: root.animate
    }

    LookNotice {
        objectName: "fetchSampleNotice"
        width: root.width
        visible: root.sample !== ""
        icon: root.installing ? "downloadSimple" : "info"
        title: I18n.t(root.installing ? "prefs.term.fetch.installing" : (root.sample === "missing" ? "prefs.term.fetch.missing.title" : "prefs.term.fetch.failed.title"))
        message: I18n.t(root.sample === "missing" ? (root.installable || root.installing ? "prefs.term.fetch.missing.desc" : "prefs.term.fetch.missing.manual") : "prefs.term.fetch.failed.desc")

        PillButton {
            objectName: "installFastfetchButton"
            visible: root.sample === "missing" && (root.installable || root.installing)
            enabled: !root.installing
            kind: "filled"
            icon: root.installing ? "" : "downloadSimple"
            text: root.installing ? I18n.t("prefs.term.look.installing") : I18n.t("prefs.term.fetch.install")
            onClicked: TerminalLookService.installFastfetch()
        }
    }

    LookNotice {
        objectName: "fetchLogoError"
        width: root.width
        visible: root.on && root.logo === "custom" && root.logoBlocked === "" && FetchModel.logoErrorKey(root.greeting) !== ""
        tone: "warning"
        icon: "warning"
        title: I18n.t("prefs.term.fetch.logo_error.title")
        message: I18n.t(FetchModel.logoErrorKey(root.greeting) || "prefs.term.fetch.logo_error.logo_format")
    }

    LookNotice {
        objectName: "fetchImageNotice"
        width: root.width
        visible: root.logo === "custom" && root.logoBlocked === "" && !!root.preview && !!root.preview.imageLogo
        icon: "image"
        title: I18n.t("prefs.term.fetch.image.title")
        message: I18n.t("prefs.term.fetch.image.desc")
    }

    Repeater {
        model: root.on ? FetchModel.shellsIn(root.greeting, "foreign").concat(FetchModel.shellsIn(root.greeting, "managed")) : []
        delegate: LookNotice {
            required property var modelData
            objectName: "fetchShellNotice:" + modelData.shell
            width: root.width
            tone: modelData.state === "managed" ? "warning" : "info"
            icon: modelData.state === "managed" ? "lock" : "info"
            title: I18n.t("prefs.term.fetch." + modelData.state + ".title", FetchModel.tilde(modelData.file, root.home))
            message: I18n.t("prefs.term.fetch." + modelData.state + ".desc", modelData.shell)
        }
    }

    // ---- look -------------------------------------------------------------
    Column {
        width: root.width
        spacing: Space.s

        KitText {
            role: "label"
            text: I18n.t("prefs.term.fetch.look")
        }
        SelectorControl {
            objectName: "fetchPresetChips"
            width: root.width
            chipLimit: 8
            translate: false
            options: TerminalLookService.fetchPresets.map(p => ({
                        "value": p.id,
                        "label": p.own ? I18n.t("term.fetch.preset.own") : p.name
                    }))
            value: root.preset
            onSelected: v => SettingsStore.set("terminal.fastfetchPreset", v)
        }
        KitText {
            width: root.width
            role: "caption"
            wrapMode: Text.WordWrap
            visible: !!root.presetInfo
            text: root.presetInfo ? I18n.t(root.presetInfo.description) : ""
        }
    }

    // ---- logo -------------------------------------------------------------
    Column {
        width: root.width
        spacing: Space.s

        KitText {
            role: "label"
            text: I18n.t("prefs.term.fetch.logo")
        }
        SelectorControl {
            objectName: "fetchLogoChips"
            width: root.width
            enabled: root.logoBlocked === ""
            translate: false
            options: FetchModel.logos().map(l => ({
                        "value": l,
                        "label": I18n.t("prefs.term.fetch.logo." + l, Brand.displayName)
                    }))
            value: root.logo
            onSelected: v => SettingsStore.set("terminal.fastfetchLogo", v)
        }
        KitText {
            width: root.width
            role: "caption"
            wrapMode: Text.WordWrap
            visible: root.logoBlocked !== ""
            text: root.logoBlocked !== "" ? I18n.t("prefs.term.fetch.logo.blocked." + root.logoBlocked) : ""
        }
        PathControl {
            objectName: "fetchLogoPath"
            width: root.width
            visible: root.logo === "custom" && root.logoBlocked === ""
            path: root.logoPath
            pathKind: "file"
            placeholder: I18n.t("prefs.term.fetch.logo.path.placeholder")
            onEdited: p => SettingsStore.set("terminal.fastfetchLogoPath", p)
        }
        KitText {
            width: root.width
            role: "caption"
            wrapMode: Text.WordWrap
            visible: root.logo === "custom" && root.logoBlocked === ""
            text: I18n.t("prefs.term.fetch.logo.path.hint")
        }
    }
}
