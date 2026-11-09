pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.components.kit
import "../../services/ai/ProviderConnect.js" as Connect
import "../../services/ai/ProviderPresets.js" as Presets

// Step 2 of the Connect sheet: API key and/or base URL of one provider,
// Test (free model listing or Ollama probe), Save, Disconnect. Local
// servers are tested as soon as the form opens and list their models.
Flickable {
    id: root

    property string provider: ""
    signal saved
    signal disconnected

    readonly property var preset: Presets.preset(provider) || ({
            id: provider,
            label: provider,
            icon: ""
        })
    readonly property bool local: preset.local === true
    readonly property bool custom: provider === "custom"
    readonly property bool needsKeyField: preset.keyRequired === true || custom
    readonly property var status: Ai.providers ? Ai.providers.status(provider) : ({})
    property bool testing: false
    property var result: null
    property bool advanced: false
    property int _generation: 0

    readonly property string description: {
        if (provider === "ollama")
            return I18n.t("ai.connect.desc.ollama");
        if (provider === "lmstudio")
            return I18n.t("ai.connect.desc.lmstudio");
        if (custom)
            return I18n.t("ai.connect.desc.custom");
        return I18n.t("ai.connect.desc.remote").arg(preset.label);
    }

    function load() {
        const c = Ai.providers ? Ai.providers.current(provider) : ({
                key: "",
                url: preset.baseUrl || "",
                curl: ""
            });
        keyField.text = c.key;
        urlField.text = c.url;
        curlField.text = c.curl;
        advanced = c.curl !== "";
        result = null;
        testing = false;
    }

    function test() {
        if (!Ai.providers)
            return;
        const generation = ++_generation;
        testing = true;
        result = null;
        Ai.providers.test(provider, keyField.text, urlField.text, r => {
            if (generation !== root._generation)
                return;
            root.testing = false;
            root.result = r;
        });
    }

    function save() {
        const fail = text => {
            result = {
                ok: false,
                verified: false,
                count: 0,
                error: text,
                models: []
            };
        };
        const invalid = Connect.validate(provider, keyField.text, urlField.text);
        if (invalid) {
            fail(I18n.t(invalid));
            return;
        }
        const started = Ai.providers && Ai.providers.save(provider, keyField.text, urlField.text, curlField.text, err => {
            if (err)
                fail(I18n.t("ai.connect.save_failed") + " " + err);
            else
                root.saved();
        });
        if (!started)
            fail(I18n.t("ai.connect.save_failed"));
    }

    function edited() {
        _generation++;
        testing = false;
        result = null;
    }

    Component.onCompleted: {
        load();
        if (local)
            test();
        else if (needsKeyField && !keyField.text)
            keyField.focusField();
    }
    onProviderChanged: load()

    clip: true
    contentWidth: width
    contentHeight: column.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {
        policy: root.contentHeight > root.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: BarLook.groupGap

        RowLayout {
            Layout.fillWidth: true
            spacing: Space.m
            StyledRect {
                implicitWidth: 52
                implicitHeight: 52
                radius: Look.radius("control")
                variant: "primary"
                ProviderIcon {
                    anchors.centerIn: parent
                    icon: root.preset.icon || ""
                    size: 28
                    color: Styling.srItem("primary")
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Space.xs
                AiText {
                    Layout.fillWidth: true
                    text: root.preset.label || root.provider
                    elide: Text.ElideRight
                    font.weight: Font.Bold
                }
                AiText {
                    role: "caption"
                    Layout.fillWidth: true
                    text: root.description
                    wrapMode: Text.Wrap
                    color: Type.secondary
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: BarLook.gap + 4

            FormField {
                id: keyField
                objectName: "connectKey"
                Layout.fillWidth: true
                visible: root.needsKeyField
                secret: true
                label: root.custom ? I18n.t("ai.connect.key_optional") : I18n.t("ai.connect.key")
                placeholder: I18n.t("ai.connect.key_placeholder")
                hint: root.status.connected && !root.local ? I18n.t("ai.connect.key_saved") : ""
                onEdited: root.edited()
            }
            Chip {
                objectName: "connectGetKey"
                visible: !!root.preset.keyUrl
                icon: Icons.arrowSquareOut
                text: I18n.t("ai.connect.get_key")
                onClicked: Qt.openUrlExternally(root.preset.keyUrl)
            }
            FormField {
                id: urlField
                objectName: "connectUrl"
                Layout.fillWidth: true
                visible: root.preset.editableUrl === true
                mono: true
                label: I18n.t("ai.connect.url")
                placeholder: root.preset.baseUrl || "https://example.com/v1"
                hint: root.local ? I18n.t("ai.connect.url_local_hint") : ""
                onEdited: root.edited()
            }
            Chip {
                visible: root.custom
                icon: root.advanced ? Icons.caretDown : Icons.caretRight
                text: I18n.t("ai.connect.advanced")
                onClicked: root.advanced = !root.advanced
            }
            FormField {
                id: curlField
                objectName: "connectCurl"
                Layout.fillWidth: true
                visible: root.custom && root.advanced
                mono: true
                label: I18n.t("ai.connect.curl")
                hint: I18n.t("ai.connect.curl_hint")
                onEdited: root.edited()
            }
        }

        TestStatus {
            objectName: "connectStatus"
            Layout.fillWidth: true
            testing: root.testing
            result: root.result
            local: root.local
        }

        ProbeModels {
            Layout.fillWidth: true
            visible: root.local && !!root.result && root.result.ok && models.length > 0
            models: root.result ? root.result.models || [] : []
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: BarLook.gap
            Chip {
                objectName: "connectDisconnect"
                visible: root.local ? root.status.state !== "hidden" : root.status.connected === true
                icon: root.local ? Icons.eye : Icons.trash
                text: root.local ? I18n.t("ai.connect.hide_local") : I18n.t("ai.connect.disconnect")
                danger: !root.local
                onClicked: {
                    Ai.providers.disconnect(root.provider);
                    root.disconnected();
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Chip {
                objectName: "connectTest"
                icon: Icons.lightning
                text: I18n.t("ai.connect.test")
                enabled: !root.testing
                onClicked: root.test()
            }
            Chip {
                objectName: "connectSave"
                active: true
                icon: Icons.checkCircle
                text: root.local ? I18n.t("ai.connect.use") : I18n.t("ai.connect.save")
                onClicked: root.save()
            }
        }
    }
}
