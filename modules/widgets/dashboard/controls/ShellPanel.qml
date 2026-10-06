pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.services
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.config
import "../../../bar/workspaces/WorkspaceNumerals.js" as WorkspaceNumerals

Item {
    id: root

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: (width - contentWidth) / 2

    // Available color names for color picker
    readonly property var colorNames: Colors.availableColorNames

    // Color picker state
    property bool colorPickerActive: false
    property var colorPickerColorNames: []
    property string colorPickerCurrentColor: ""
    property string colorPickerDialogTitle: ""
    property var colorPickerCallback: null

    // bar.json "layout" is one object: copy, change one field, reassign
    function barLayoutField(field) {
        const layout = Config.bar.layout;
        return layout && layout[field] !== undefined ? layout[field] : null;
    }

    function setBarLayoutField(field, value) {
        const next = JSON.parse(JSON.stringify(Config.bar.layout || {}));
        if (JSON.stringify(next[field]) === JSON.stringify(value))
            return;
        next[field] = value;
        GlobalStates.markShellChanged();
        Config.bar.layout = next;
    }

    function parseModuleList(text) {
        return text.split(",").map(id => id.trim()).filter(id => id.length > 0);
    }

    function openColorPicker(colorNames, currentColor, dialogTitle, callback) {
        colorPickerColorNames = colorNames;
        colorPickerCurrentColor = currentColor;
        colorPickerDialogTitle = dialogTitle;
        colorPickerCallback = callback;
        colorPickerActive = true;
    }

    function closeColorPicker() {
        colorPickerActive = false;
        colorPickerCallback = null;
    }

    function handleColorSelected(color) {
        if (colorPickerCallback) {
            colorPickerCallback(color);
        }
        colorPickerCurrentColor = color;
    }

    property string currentSection: ""

    component SectionButton: StyledRect {
        id: sectionBtn
        required property string text
        required property string sectionId

        property bool isHovered: false

        variant: isHovered ? "focus" : "pane"
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        radius: Styling.radius(0)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            Text {
                text: sectionBtn.text
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                font.bold: true
                color: Colors.overBackground
                Layout.fillWidth: true
            }

            Text {
                text: Icons.caretRight
                font.family: Icons.font
                font.pixelSize: 20
                color: Colors.overSurfaceVariant
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: sectionBtn.isHovered = true
            onExited: sectionBtn.isHovered = false
            onClicked: root.currentSection = sectionBtn.sectionId
        }
    }

    // Inline component for toggle rows
    component ToggleRow: SettingsToggleRow {}

    // Inline component for number input rows
    component NumberInputRow: SettingsNumberRow {}

    // Inline component for text input rows
    component TextInputRow: RowLayout {
        id: textInputRowRoot
        property string label: ""
        property string value: ""
        property string placeholder: ""
        signal valueEdited(string newValue)

        Layout.fillWidth: true
        spacing: 8

        Text {
            text: textInputRowRoot.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overBackground
            Layout.preferredWidth: 100
        }

        StyledRect {
            variant: "common"
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: Styling.radius(-2)

            TextInput {
                id: textInputField
                anchors.fill: parent
                anchors.margins: 8
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overBackground
                selectByMouse: true
                clip: true
                verticalAlignment: TextInput.AlignVCenter

                // Sync text when external value changes
                readonly property string configValue: textInputRowRoot.value
                onConfigValueChanged: {
                    if (!activeFocus && text !== configValue) {
                        text = configValue;
                    }
                }
                Component.onCompleted: text = configValue

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: textInputRowRoot.placeholder
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    color: Colors.overSurfaceVariant
                    visible: textInputField.text === ""
                }

                onEditingFinished: {
                    textInputRowRoot.valueEdited(text);
                }
            }
        }
    }

    // Inline component for segmented selector rows
    component SelectorRow: SettingsSelectorRow {}

    // Inline component for screen list selection
    component ScreenListRow: ColumnLayout {
        id: screenListRowRoot
        property string label: I18n.t("shell.screens")
        property var selectedScreens: []  // Array of screen names
        signal screensChanged(var newList)

        Layout.fillWidth: true
        spacing: 4

        Text {
            text: screenListRowRoot.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.Medium
            color: Colors.overSurfaceVariant
        }

        Text {
            text: I18n.t("shell.screens_empty")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.outline
            Layout.bottomMargin: 4
        }

        Flow {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: Quickshell.screens

                delegate: StyledRect {
                    id: screenButton
                    required property var modelData
                    required property int index

                    readonly property string screenName: modelData.name
                    readonly property bool isSelected: {
                        const list = screenListRowRoot.selectedScreens;
                        return list && list.length > 0 && list.includes(screenName);
                    }
                    property bool isHovered: false

                    variant: isSelected ? "primary" : (isHovered ? "focus" : "common")
                    width: screenLabel.implicitWidth + 24
                    height: 32
                    radius: Styling.radius(-2)

                    Text {
                        id: screenLabel
                        anchors.centerIn: parent
                        text: screenButton.screenName
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.bold: screenButton.isSelected
                        color: screenButton.item
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: screenButton.isHovered = true
                        onExited: screenButton.isHovered = false

                        onClicked: {
                            let currentList = screenListRowRoot.selectedScreens ? [...screenListRowRoot.selectedScreens] : [];
                            const idx = currentList.indexOf(screenButton.screenName);
                            if (idx >= 0) {
                                currentList.splice(idx, 1);
                            } else {
                                currentList.push(screenButton.screenName);
                            }
                            screenListRowRoot.screensChanged(currentList);
                        }
                    }
                }
            }
        }
    }

    // Main content
    Flickable {
        id: mainFlickable
        anchors.fill: parent
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: !root.colorPickerActive

        // Horizontal slide + fade animation
        opacity: root.colorPickerActive ? 0 : 1
        transform: Translate {
            x: root.colorPickerActive ? -30 : 0

            Behavior on x {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutQuart
                }
            }
        }

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutQuart
            }
        }

        ColumnLayout {
            id: mainColumn
            width: mainFlickable.width
            spacing: 8

            // Header wrapper
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: titlebar.height

                PanelTitlebar {
                    id: titlebar
                    width: root.contentWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    title: root.currentSection === "" ? I18n.t("shell.shell") : I18n.t("settings.shell." + root.currentSection)
                    statusText: GlobalStates.shellHasChanges ? I18n.t("common.unsaved_changes") : ""
                    statusColor: Colors.error

                    actions: {
                        let baseActions = [
                            {
                                icon: Icons.arrowCounterClockwise,
                                tooltip: I18n.t("common.discard_changes"),
                                enabled: GlobalStates.shellHasChanges,
                                onClicked: function () {
                                    GlobalStates.discardShellChanges();
                                }
                            },
                            {
                                icon: Icons.disk,
                                tooltip: I18n.t("common.apply_changes"),
                                enabled: GlobalStates.shellHasChanges,
                                onClicked: function () {
                                    GlobalStates.applyShellChanges();
                                }
                            }
                        ];

                        if (root.currentSection !== "") {
                            return [
                                {
                                    icon: Icons.arrowLeft,
                                    tooltip: I18n.t("common.back"),
                                    onClicked: function () {
                                        root.currentSection = "";
                                    }
                                }
                            ].concat(baseActions);
                        }

                        return baseActions;
                    }
                }
            }

            // Content wrapper - centered
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: contentColumn.implicitHeight

                ColumnLayout {
                    id: contentColumn
                    width: root.contentWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    // ═══════════════════════════════════════════════════════════════
                    // MENU SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === ""
                        Layout.fillWidth: true
                        spacing: 8

                        SectionButton {
                            text: I18n.t("settings.shell.bar")
                            sectionId: "bar"
                        }
                        SectionButton {
                            text: I18n.t("settings.shell.sidebar")
                            sectionId: "sidebar"
                        }
                        SectionButton {
                            text: I18n.t("settings.shell.frame")
                            sectionId: "frame"
                        }
                        SectionButton {
                            text: I18n.t("settings.shell.notch")
                            sectionId: "notch"
                        }
                        SectionButton {
                            text: I18n.t("settings.shell.workspaces")
                            sectionId: "workspaces"
                        }
                        SectionButton {
                            text: I18n.t("settings.shell.overview")
                            sectionId: "overview"
                        }
                        SectionButton {
                            text: I18n.t("settings.shell.dock")
                            sectionId: "dock"
                        }
                        SectionButton {
                            text: I18n.t("settings.shell.lockscreen")
                            sectionId: "lockscreen"
                        }
                        SectionButton {
                            text: I18n.t("settings.shell.desktop")
                            sectionId: "desktop"
                        }
                    }

                    // ═══════════════════════════════════════════════════════════════
                    // BAR SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === "bar"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: I18n.t("settings.shell.bar")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        SelectorRow {
                            label: ""
                            options: [
                                {
                                    label: I18n.t("common.top"),
                                    value: "top",
                                    icon: Icons.arrowUp
                                },
                                {
                                    label: I18n.t("common.bottom"),
                                    value: "bottom",
                                    icon: Icons.arrowDown
                                },
                                {
                                    label: I18n.t("common.left"),
                                    value: "left",
                                    icon: Icons.arrowLeft
                                },
                                {
                                    label: I18n.t("common.right"),
                                    value: "right",
                                    icon: Icons.arrowRight
                                }
                            ]
                            value: Config.bar.position ?? "top"
                            onValueSelected: newValue => {
                                if (newValue !== Config.bar.position) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.position = newValue;
                                }
                            }
                        }

                        TextInputRow {
                            label: I18n.t("shell.launcher_icon")
                            value: Config.bar.launcherIcon ?? ""
                            placeholder: I18n.t("theme.symbol_or_icon")
                            onValueEdited: newValue => {
                                if (newValue !== Config.bar.launcherIcon) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.launcherIcon = newValue;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.launcher_icon_tint")
                            checked: Config.bar.launcherIconTint ?? true
                            onToggled: value => {
                                if (value !== Config.bar.launcherIconTint) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.launcherIconTint = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.launcher_icon_full_tint")
                            checked: Config.bar.launcherIconFullTint ?? true
                            onToggled: value => {
                                if (value !== Config.bar.launcherIconFullTint) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.launcherIconFullTint = value;
                                }
                            }
                        }

                        NumberInputRow {
                            label: I18n.t("shell.launcher_icon_size")
                            value: Config.bar.launcherIconSize ?? 24
                            minValue: 12
                            maxValue: 64
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.bar.launcherIconSize) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.launcherIconSize = newValue;
                                }
                            }
                        }

                        SelectorRow {
                            label: I18n.t("shell.pill_style")
                            options: [
                                {
                                    label: I18n.t("common.default"),
                                    value: "default"
                                },
                                {
                                    label: I18n.t("shell.squished"),
                                    value: "squished"
                                }
                            ]
                            value: Config.bar.pillStyle ?? "default"
                            onValueSelected: newValue => {
                                if (newValue !== Config.bar.pillStyle) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.pillStyle = newValue;
                                }
                            }
                        }

                        SelectorRow {
                            label: I18n.t("shell.bar_style")
                            options: [
                                {
                                    label: I18n.t("shell.bar_style_classic"),
                                    value: "classic"
                                },
                                {
                                    label: I18n.t("shell.bar_style_islands"),
                                    value: "islands"
                                }
                            ]
                            value: root.barLayoutField("style") ?? "classic"
                            onValueSelected: newValue => root.setBarLayoutField("style", newValue)
                        }

                        // Module order: comma-separated ids (see BarLayout.js)
                        TextInputRow {
                            label: I18n.t("shell.bar_modules_left")
                            value: Array.from(root.barLayoutField("left") ?? []).join(", ")
                            placeholder: "launcher, workspaces"
                            onValueEdited: newValue => root.setBarLayoutField("left", root.parseModuleList(newValue))
                        }

                        TextInputRow {
                            label: I18n.t("shell.bar_modules_right")
                            value: Array.from(root.barLayoutField("right") ?? []).join(", ")
                            placeholder: "controls, battery, clock"
                            onValueEdited: newValue => root.setBarLayoutField("right", root.parseModuleList(newValue))
                        }

                        TextInputRow {
                            label: I18n.t("shell.bar_modules_drawer")
                            value: Array.from(root.barLayoutField("drawer") ?? []).join(", ")
                            placeholder: "systray, tools, power"
                            onValueEdited: newValue => root.setBarLayoutField("drawer", root.parseModuleList(newValue))
                        }

                        ToggleRow {
                            label: I18n.t("shell.use_12h_format")
                            checked: Config.bar.use12hFormat ?? false
                            onToggled: value => {
                                if (value !== Config.bar.use12hFormat) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.use12hFormat = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.clock_show_date")
                            checked: Config.bar.clockShowDate ?? false
                            onToggled: value => {
                                if (value !== Config.bar.clockShowDate) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.clockShowDate = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.compact_bar")
                            checked: Config.bar.compact ?? false
                            onToggled: value => {
                                if (value !== Config.bar.compact) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.compact = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.enable_firefox_player")
                            checked: Config.bar.enableFirefoxPlayer ?? false
                            onToggled: value => {
                                if (value !== Config.bar.enableFirefoxPlayer) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.enableFirefoxPlayer = value;
                                }
                            }
                        }

                        Separator {
                            Layout.fillWidth: true
                        }

                        BarActivitiesSettings {
                            Layout.fillWidth: true
                        }

                        Separator {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: I18n.t("shell.autohide")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        ToggleRow {
                            label: I18n.t("shell.pinned_on_startup")
                            checked: Config.bar.pinnedOnStartup ?? true
                            onToggled: value => {
                                if (value !== Config.bar.pinnedOnStartup) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.pinnedOnStartup = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.hover_to_reveal")
                            checked: Config.bar.hoverToReveal ?? true
                            onToggled: value => {
                                if (value !== Config.bar.hoverToReveal) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.hoverToReveal = value;
                                }
                            }
                        }

                        NumberInputRow {
                            label: I18n.t("shell.hover_region_height")
                            value: Config.bar.hoverRegionHeight ?? 8
                            minValue: 0
                            maxValue: 32
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.bar.hoverRegionHeight) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.hoverRegionHeight = newValue;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.show_pin_button")
                            checked: Config.bar.showPinButton ?? true
                            onToggled: value => {
                                if (value !== Config.bar.showPinButton) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.showPinButton = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.available_on_fullscreen")
                            checked: Config.bar.availableOnFullscreen ?? false
                            onToggled: value => {
                                if (value !== Config.bar.availableOnFullscreen) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.availableOnFullscreen = value;
                                }
                            }
                        }

                        ScreenListRow {
                            label: I18n.t("shell.screens")
                            selectedScreens: Config.bar.screenList ?? []
                            onScreensChanged: newList => {
                                GlobalStates.markShellChanged();
                                Config.bar.screenList = newList;
                            }
                        }
                    }

                    // ═══════════════════════════════════════════════════════════════
                    // FRAME SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === "frame"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: I18n.t("settings.shell.frame")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        ToggleRow {
                            label: I18n.t("shell.frame.enabled")
                            checked: Config.bar.frameEnabled ?? false
                            onToggled: value => {
                                if (value !== Config.bar.frameEnabled) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.frameEnabled = value;
                                }
                            }
                        }

                        NumberInputRow {
                            label: I18n.t("shell.frame.thickness")
                            value: Config.bar.frameThickness ?? 6
                            minValue: 0
                            maxValue: 40
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.bar.frameThickness) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.frameThickness = newValue;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.frame.contain_bar")
                            checked: Config.bar.containBar ?? false
                            onToggled: value => {
                                if (value !== Config.bar.containBar) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.containBar = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.frame.keep_bar_shadow")
                            checked: Config.bar.keepBarShadow ?? false
                            visible: Config.bar.containBar ?? false
                            onToggled: value => {
                                if (value !== Config.bar.keepBarShadow) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.keepBarShadow = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.frame.keep_bar_border")
                            checked: Config.bar.keepBarBorder ?? false
                            visible: Config.bar.containBar ?? false
                            onToggled: value => {
                                if (value !== Config.bar.keepBarBorder) {
                                    GlobalStates.markShellChanged();
                                    Config.bar.keepBarBorder = value;
                                }
                            }
                        }
                    }

                    Separator {
                        Layout.fillWidth: true
                        visible: false
                    }

                    // ═══════════════════════════════════════════════════════════════
                    // NOTCH SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === "notch"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: I18n.t("settings.shell.notch")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        SelectorRow {
                            label: ""
                            options: [
                                {
                                    label: I18n.t("common.top"),
                                    value: "top",
                                    icon: Icons.arrowUp
                                },
                                {
                                    label: I18n.t("common.bottom"),
                                    value: "bottom",
                                    icon: Icons.arrowDown
                                }
                            ]
                            value: Config.notch.position ?? "top"
                            onValueSelected: newValue => {
                                if (newValue !== Config.notch.position) {
                                    GlobalStates.markShellChanged();
                                    Config.notch.position = newValue;
                                }
                            }
                        }

                        SelectorRow {
                            label: ""
                            options: [
                                {
                                    label: I18n.t("common.default"),
                                    value: "default"
                                },
                                {
                                    label: I18n.t("shell.dock.island"),
                                    value: "island"
                                }
                            ]
                            value: Config.notch.theme ?? "default"
                            onValueSelected: newValue => {
                                if (newValue !== Config.notch.theme) {
                                    GlobalStates.markShellChanged();
                                    Config.notch.theme = newValue;
                                }
                            }
                        }

                        NumberInputRow {
                            label: I18n.t("shell.hover_region_height")
                            value: Config.notch.hoverRegionHeight ?? 8
                            minValue: 0
                            maxValue: 32
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.notch.hoverRegionHeight) {
                                    GlobalStates.markShellChanged();
                                    Config.notch.hoverRegionHeight = newValue;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.notch.keep_hidden")
                            checked: Config.notch.keepHidden ?? false
                            onToggled: value => {
                                if (value !== Config.notch.keepHidden) {
                                    GlobalStates.markShellChanged();
                                    Config.notch.keepHidden = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.notch.disable_hover_expansion")
                            checked: Config.notch.disableHoverExpansion ?? true
                            onToggled: value => {
                                if (value !== Config.notch.disableHoverExpansion) {
                                    GlobalStates.markShellChanged();
                                    Config.notch.disableHoverExpansion = value;
                                }
                            }
                        }

                        SelectorRow {
                            label: I18n.t("shell.notch.expand_on")
                            options: [
                                {
                                    label: I18n.t("shell.notch.expand_on_hover"),
                                    value: "hover"
                                },
                                {
                                    label: I18n.t("shell.notch.expand_on_click"),
                                    value: "click"
                                }
                            ]
                            value: Config.notch.expandOn ?? "hover"
                            onValueSelected: newValue => {
                                if (newValue !== Config.notch.expandOn) {
                                    GlobalStates.markShellChanged();
                                    Config.notch.expandOn = newValue;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.notch.visualizer")
                            checked: Config.notch.visualizer ?? true
                            onToggled: value => {
                                if (value !== Config.notch.visualizer) {
                                    GlobalStates.markShellChanged();
                                    Config.notch.visualizer = value;
                                }
                            }
                        }

                        Separator {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: I18n.t("shell.no_media_display")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        SelectorRow {
                            label: ""
                            options: [
                                {
                                    label: I18n.t("shell.notch.user_host"),
                                    value: "userHost",
                                    icon: Icons.user
                                },
                                {
                                    label: I18n.t("shell.notch.compositor"),
                                    value: "compositor",
                                    icon: Icons.compositor
                                },
                                {
                                    label: I18n.t("theme.custom"),
                                    value: "custom",
                                    icon: Icons.textT
                                }
                            ]
                            value: Config.notch.noMediaDisplay ?? "userHost"
                            onValueSelected: newValue => {
                                if (newValue !== Config.notch.noMediaDisplay) {
                                    GlobalStates.markShellChanged();
                                    Config.notch.noMediaDisplay = newValue;
                                }
                            }
                        }

                        TextInputRow {
                            label: I18n.t("shell.notch.custom_text")
                            visible: Config.notch.noMediaDisplay === "custom"
                            value: Config.notch.customText ?? Brand.displayName
                            placeholder: I18n.t("shell.notch.enter_text")
                            onValueEdited: newValue => {
                                if (newValue !== Config.notch.customText) {
                                    GlobalStates.markShellChanged();
                                    Config.notch.customText = newValue;
                                }
                            }
                        }
                    }

                    Separator {
                        Layout.fillWidth: true
                        visible: false
                    }

                    // ═══════════════════════════════════════════════════════════════
                    // WORKSPACES SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === "workspaces"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: I18n.t("settings.shell.workspaces")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        NumberInputRow {
                            label: I18n.t("shell.workspaces.shown")
                            value: Config.workspaces.shown ?? 10
                            minValue: 1
                            maxValue: 20
                            onValueEdited: newValue => {
                                if (newValue !== Config.workspaces.shown) {
                                    GlobalStates.markShellChanged();
                                    Config.workspaces.shown = newValue;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.workspaces.show_app_icons")
                            checked: Config.workspaces.showAppIcons ?? true
                            onToggled: value => {
                                if (value !== Config.workspaces.showAppIcons) {
                                    GlobalStates.markShellChanged();
                                    Config.workspaces.showAppIcons = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.workspaces.always_show_numbers")
                            checked: Config.workspaces.alwaysShowNumbers ?? false
                            onToggled: value => {
                                if (value !== Config.workspaces.alwaysShowNumbers) {
                                    GlobalStates.markShellChanged();
                                    Config.workspaces.alwaysShowNumbers = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.workspaces.show_numbers")
                            checked: Config.workspaces.showNumbers ?? false
                            onToggled: value => {
                                if (value !== Config.workspaces.showNumbers) {
                                    GlobalStates.markShellChanged();
                                    Config.workspaces.showNumbers = value;
                                }
                            }
                        }

                        // One option per registered numeral system, previewed as "1 2 3".
                        SelectorRow {
                            label: I18n.t("shell.workspaces.numeral_style")
                            options: WorkspaceNumerals.ids().map(id => ({
                                        label: [1, 2, 3].map(n => WorkspaceNumerals.format(id, n)).join(" "),
                                        value: id
                                    }))
                            value: Config.workspaces.numeralStyle ?? WorkspaceNumerals.DEFAULT_ID
                            onValueSelected: newValue => {
                                if (newValue !== Config.workspaces.numeralStyle) {
                                    GlobalStates.markShellChanged();
                                    Config.workspaces.numeralStyle = newValue;
                                }
                            }
                        }

                        TextInputRow {
                            label: I18n.t("shell.workspaces.numeral_font")
                            value: Config.workspaces.numeralFont ?? ""
                            placeholder: I18n.t("shell.workspaces.numeral_font_auto")
                            onValueEdited: newValue => {
                                if (newValue !== Config.workspaces.numeralFont) {
                                    GlobalStates.markShellChanged();
                                    Config.workspaces.numeralFont = newValue.trim();
                                }
                            }
                        }

                        // Niri only has dynamic workspaces: the effective
                        // state is forced on and the switch is inert.
                        ToggleRow {
                            label: I18n.t("shell.workspaces.dynamic")
                            checked: Config.workspaces.dynamic || YozdService.compositorName === "niri"
                            enabled: YozdService.compositorName !== "niri"
                            onToggled: value => {
                                if (value !== Config.workspaces.dynamic) {
                                    GlobalStates.markShellChanged();
                                    Config.workspaces.dynamic = value;
                                }
                            }
                        }
                    }

                    Separator {
                        Layout.fillWidth: true
                        visible: false
                    }

                    // ═══════════════════════════════════════════════════════════════
                    // OVERVIEW SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === "overview"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: I18n.t("settings.shell.overview")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        SelectorRow {
                            label: I18n.t("shell.overview.style")
                            options: [
                                {
                                    label: I18n.t("settings.shell.overview_style_grid"),
                                    value: "grid"
                                },
                                {
                                    label: I18n.t("settings.shell.overview_style_strip"),
                                    value: "strip"
                                }
                            ]
                            value: Config.overview.style ?? "grid"
                            onValueSelected: newValue => {
                                if (newValue !== Config.overview.style) {
                                    GlobalStates.markShellChanged();
                                    Config.overview.style = newValue;
                                }
                            }
                        }

                        NumberInputRow {
                            label: I18n.t("shell.overview.rows")
                            value: Config.overview.rows ?? 2
                            minValue: 1
                            maxValue: 5
                            onValueEdited: newValue => {
                                if (newValue !== Config.overview.rows) {
                                    GlobalStates.markShellChanged();
                                    Config.overview.rows = newValue;
                                }
                            }
                        }

                        NumberInputRow {
                            label: I18n.t("shell.overview.columns")
                            value: Config.overview.columns ?? 5
                            minValue: 1
                            maxValue: 10
                            onValueEdited: newValue => {
                                if (newValue !== Config.overview.columns) {
                                    GlobalStates.markShellChanged();
                                    Config.overview.columns = newValue;
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: I18n.t("shell.overview.scale")
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                color: Colors.overBackground
                                Layout.preferredWidth: 100
                            }

                            StyledSlider {
                                id: overviewScaleSlider
                                Layout.fillWidth: true
                                Layout.preferredHeight: 20
                                progressColor: Styling.srItem("overprimary")
                                tooltipText: `${(value * 0.2).toFixed(2)}`
                                scroll: true
                                stepSize: 0.05  // 0.05 * 0.2 = 0.01 scale steps
                                snapMode: "always"

                                readonly property real configValue: (Config.overview.scale ?? 0.15) / 0.2

                                onConfigValueChanged: {
                                    if (Math.abs(value - configValue) > 0.001) {
                                        value = configValue;
                                    }
                                }

                                Component.onCompleted: value = configValue

                                onValueChanged: {
                                    let newScale = Math.round(value * 0.2 * 100) / 100;  // Round to 2 decimals
                                    if (Math.abs(newScale - (Config.overview.scale ?? 0.15)) > 0.001) {
                                        GlobalStates.markShellChanged();
                                        Config.overview.scale = newScale;
                                    }
                                }
                            }

                            Text {
                                text: ((Config.overview.scale ?? 0.15)).toFixed(2)
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                color: Colors.overBackground
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: 40
                            }
                        }

                        NumberInputRow {
                            label: I18n.t("shell.overview.workspace_spacing")
                            value: Config.overview.workspaceSpacing ?? 4
                            minValue: 0
                            maxValue: 20
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.overview.workspaceSpacing) {
                                    GlobalStates.markShellChanged();
                                    Config.overview.workspaceSpacing = newValue;
                                }
                            }
                        }
                    }

                    Separator {
                        Layout.fillWidth: true
                        visible: false
                    }

                    // ═══════════════════════════════════════════════════════════════
                    // DOCK SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === "dock"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: I18n.t("settings.shell.dock")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        ToggleRow {
                            label: I18n.t("shell.dock.enabled")
                            checked: Config.dock.enabled ?? false
                            onToggled: value => {
                                if (value !== Config.dock.enabled) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.enabled = value;
                                }
                            }
                        }

                        SelectorRow {
                            label: I18n.t("shell.position")
                            options: [
                                {
                                    label: I18n.t("common.top"),
                                    value: "top",
                                    icon: Icons.arrowUp
                                },
                                {
                                    label: I18n.t("common.bottom"),
                                    value: "bottom",
                                    icon: Icons.arrowDown
                                },
                                {
                                    label: I18n.t("common.left"),
                                    value: "left",
                                    icon: Icons.arrowLeft
                                },
                                {
                                    label: I18n.t("common.right"),
                                    value: "right",
                                    icon: Icons.arrowRight
                                }
                            ]
                            value: Config.dock.position ?? "bottom"
                            onValueSelected: newValue => {
                                if (newValue !== Config.dock.position) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.position = newValue;
                                }
                            }
                        }

                        SelectorRow {
                            label: I18n.t("shell.dock.theme")
                            options: [
                                {
                                    label: I18n.t("common.default"),
                                    value: "default"
                                },
                                {
                                    label: I18n.t("shell.dock.floating"),
                                    value: "floating"
                                },
                                {
                                    label: I18n.t("shell.dock.integrated"),
                                    value: "integrated"
                                }
                            ]
                            value: Config.dock.theme ?? "default"
                            onValueSelected: newValue => {
                                if (newValue !== Config.dock.theme) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.theme = newValue;
                                }
                            }
                        }

                        NumberInputRow {
                            label: I18n.t("shell.dock.height")
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            value: Config.dock.height ?? 48
                            minValue: 32
                            maxValue: 128
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.dock.height) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.height = newValue;
                                }
                            }
                        }

                        NumberInputRow {
                            label: I18n.t("shell.dock.icon_size")
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            value: Config.dock.iconSize ?? 40
                            minValue: 24
                            maxValue: 96
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.dock.iconSize) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.iconSize = newValue;
                                }
                            }
                        }

                        NumberInputRow {
                            label: I18n.t("shell.dock.spacing")
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            value: Config.dock.spacing ?? 10
                            minValue: 0
                            maxValue: 32
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.dock.spacing) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.spacing = newValue;
                                }
                            }
                        }

                        NumberInputRow {
                            label: I18n.t("shell.dock.margin")
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            value: Config.dock.margin ?? 8
                            minValue: 0
                            maxValue: 32
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.dock.margin) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.margin = newValue;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.hover_to_reveal")
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            checked: Config.dock.hoverToReveal ?? true
                            onToggled: value => {
                                if (value !== Config.dock.hoverToReveal) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.hoverToReveal = value;
                                }
                            }
                        }

                        NumberInputRow {
                            label: I18n.t("shell.dock.hover_region")
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            value: Config.dock.hoverRegionHeight ?? 8
                            minValue: 0
                            maxValue: 32
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.dock.hoverRegionHeight) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.hoverRegionHeight = newValue;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.pinned_on_startup")
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            checked: Config.dock.pinnedOnStartup ?? true
                            onToggled: value => {
                                if (value !== Config.dock.pinnedOnStartup) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.pinnedOnStartup = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.show_pin_button")
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            checked: Config.dock.showPinButton ?? true
                            onToggled: value => {
                                if (value !== Config.dock.showPinButton) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.showPinButton = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.available_on_fullscreen")
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            checked: Config.dock.availableOnFullscreen ?? false
                            onToggled: value => {
                                if (value !== Config.dock.availableOnFullscreen) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.availableOnFullscreen = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.dock.keep_hidden")
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            checked: Config.dock.keepHidden ?? false
                            onToggled: value => {
                                if (value !== Config.dock.keepHidden) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.keepHidden = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.show_running_indicators")
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            checked: Config.dock.showRunningIndicators ?? true
                            onToggled: value => {
                                if (value !== Config.dock.showRunningIndicators) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.showRunningIndicators = value;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.show_overview_button")
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            checked: Config.dock.showOverviewButton ?? true
                            onToggled: value => {
                                if (value !== Config.dock.showOverviewButton) {
                                    GlobalStates.markShellChanged();
                                    Config.dock.showOverviewButton = value;
                                }
                            }
                        }

                        ScreenListRow {
                            label: I18n.t("shell.screens")
                            visible: (Config.dock.theme ?? "default") !== "integrated"
                            selectedScreens: Config.dock.screenList ?? []
                            onScreensChanged: newList => {
                                GlobalStates.markShellChanged();
                                Config.dock.screenList = newList;
                            }
                        }
                    }

                    Separator {
                        Layout.fillWidth: true
                        visible: false
                    }

                    // ═══════════════════════════════════════════════════════════════
                    // LOCKSCREEN SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === "lockscreen"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: I18n.t("settings.shell.lockscreen")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        SelectorRow {
                            label: ""
                            options: [
                                {
                                    label: I18n.t("common.top"),
                                    value: "top",
                                    icon: Icons.arrowUp
                                },
                                {
                                    label: I18n.t("common.bottom"),
                                    value: "bottom",
                                    icon: Icons.arrowDown
                                }
                            ]
                            value: Config.lockscreen.position ?? "bottom"
                            onValueSelected: newValue => {
                                if (newValue !== Config.lockscreen.position) {
                                    GlobalStates.markShellChanged();
                                    Config.lockscreen.position = newValue;
                                }
                            }
                        }
                    }

                    Separator {
                        Layout.fillWidth: true
                        visible: false
                    }

                    // ═══════════════════════════════════════════════════════════════
                    // DESKTOP SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === "desktop"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: I18n.t("settings.shell.desktop")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        ToggleRow {
                            label: I18n.t("shell.desktop.enabled")
                            checked: Config.desktop.enabled ?? false
                            onToggled: value => {
                                if (value !== Config.desktop.enabled) {
                                    GlobalStates.markShellChanged();
                                    Config.desktop.enabled = value;
                                }
                            }
                        }

                        NumberInputRow {
                            label: I18n.t("shell.desktop.icon_size")
                            value: Config.desktop.iconSize ?? 40
                            minValue: 24
                            maxValue: 96
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.desktop.iconSize) {
                                    GlobalStates.markShellChanged();
                                    Config.desktop.iconSize = newValue;
                                }
                            }
                        }

                        NumberInputRow {
                            label: I18n.t("shell.desktop.vertical_spacing")
                            value: Config.desktop.spacingVertical ?? 16
                            minValue: 0
                            maxValue: 48
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.desktop.spacingVertical) {
                                    GlobalStates.markShellChanged();
                                    Config.desktop.spacingVertical = newValue;
                                }
                            }
                        }

                        // Text Color with ColorButton
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: I18n.t("shell.desktop.text_color")
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                color: Colors.overBackground
                                Layout.preferredWidth: 100
                            }

                            ColorButton {
                                id: desktopTextColorButton
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48
                                colorNames: root.colorNames
                                currentColor: Config.desktop.textColor ?? "overBackground"
                                dialogTitle: I18n.t("shell.desktop.text_color")
                                compact: false

                                onOpenColorPicker: (colorNames, currentColor, dialogTitle) => {
                                    root.openColorPicker(colorNames, currentColor, dialogTitle, function (color) {
                                        if (color !== Config.desktop.textColor) {
                                            GlobalStates.markShellChanged();
                                            Config.desktop.textColor = color;
                                        }
                                    });
                                }
                            }
                        }

                        Text {
                            text: I18n.t("shell.desktop.wallpaper_transition")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.topMargin: 8
                            Layout.bottomMargin: -4
                        }

                        SelectorRow {
                            label: ""
                            options: [
                                {
                                    label: I18n.t("shell.desktop.transition.grow"),
                                    value: "grow"
                                },
                                {
                                    label: I18n.t("shell.desktop.transition.wipe"),
                                    value: "wipe"
                                },
                                {
                                    label: I18n.t("shell.desktop.transition.dissolve"),
                                    value: "dissolve"
                                },
                                {
                                    label: I18n.t("shell.desktop.transition.fade"),
                                    value: "fade"
                                }
                            ]
                            fallbackToFirst: false
                            value: Config.desktop.wallpaperTransition ?? "grow"
                            onValueSelected: newValue => {
                                if (newValue !== Config.desktop.wallpaperTransition) {
                                    GlobalStates.markShellChanged();
                                    Config.desktop.wallpaperTransition = newValue;
                                }
                            }
                        }

                        SelectorRow {
                            label: ""
                            options: [
                                {
                                    label: I18n.t("shell.desktop.transition.random"),
                                    value: "random",
                                    icon: Icons.shuffle
                                },
                                {
                                    label: I18n.t("shell.desktop.transition.none"),
                                    value: "none",
                                    icon: Icons.cancel
                                }
                            ]
                            fallbackToFirst: false
                            value: Config.desktop.wallpaperTransition ?? "grow"
                            onValueSelected: newValue => {
                                if (newValue !== Config.desktop.wallpaperTransition) {
                                    GlobalStates.markShellChanged();
                                    Config.desktop.wallpaperTransition = newValue;
                                }
                            }
                        }

                        NumberInputRow {
                            label: I18n.t("shell.desktop.wallpaper_transition_duration")
                            value: Config.desktop.wallpaperTransitionDuration ?? 800
                            minValue: 0
                            maxValue: 5000
                            suffix: "ms"
                            onValueEdited: newValue => {
                                if (newValue !== Config.desktop.wallpaperTransitionDuration) {
                                    GlobalStates.markShellChanged();
                                    Config.desktop.wallpaperTransitionDuration = newValue;
                                }
                            }
                        }

                        DepthClockSettings {}
                    }

                    Separator {
                        Layout.fillWidth: true
                        visible: false
                    }

                    // ═══════════════════════════════════════════════════════════════
                    // SIDEBAR SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === "sidebar"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: I18n.t("settings.shell.sidebar")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        SelectorRow {
                            label: I18n.t("shell.position")
                            options: [
                                {
                                    label: I18n.t("common.left"),
                                    value: "left",
                                    icon: Icons.arrowLeft
                                },
                                {
                                    label: I18n.t("common.right"),
                                    value: "right",
                                    icon: Icons.arrowRight
                                }
                            ]
                            value: Config.ai.sidebarPosition ?? "right"
                            onValueSelected: newValue => {
                                if (newValue !== Config.ai.sidebarPosition) {
                                    GlobalStates.markShellChanged();
                                    Config.ai.sidebarPosition = newValue;
                                }
                            }
                        }

                        NumberInputRow {
                            label: I18n.t("shell.sidebar.width")
                            value: Config.ai.sidebarWidth ?? 400
                            minValue: 300
                            maxValue: 800
                            suffix: "px"
                            onValueEdited: newValue => {
                                if (newValue !== Config.ai.sidebarWidth) {
                                    GlobalStates.markShellChanged();
                                    Config.ai.sidebarWidth = newValue;
                                }
                            }
                        }

                        ToggleRow {
                            label: I18n.t("shell.pinned_on_startup")
                            checked: Config.ai.sidebarPinnedOnStartup ?? false
                            onToggled: value => {
                                if (value !== Config.ai.sidebarPinnedOnStartup) {
                                    GlobalStates.markShellChanged();
                                    Config.ai.sidebarPinnedOnStartup = value;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Color picker view (shown when colorPickerActive)
    Item {
        id: colorPickerContainer
        anchors.fill: parent
        clip: true

        // Horizontal slide + fade animation (enters from right)
        opacity: root.colorPickerActive ? 1 : 0
        transform: Translate {
            x: root.colorPickerActive ? 0 : 30

            Behavior on x {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutQuart
                }
            }
        }

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutQuart
            }
        }

        // Prevent interaction when hidden
        enabled: root.colorPickerActive

        // Block interaction with elements behind when active
        MouseArea {
            anchors.fill: parent
            enabled: root.colorPickerActive
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onPressed: event => event.accepted = true
            onReleased: event => event.accepted = true
            onWheel: event => event.accepted = true
        }

        ColorPickerView {
            id: colorPickerContent
            anchors.fill: parent
            anchors.leftMargin: root.sideMargin
            anchors.rightMargin: root.sideMargin
            colorNames: root.colorPickerColorNames
            currentColor: root.colorPickerCurrentColor
            dialogTitle: root.colorPickerDialogTitle

            onColorSelected: color => root.handleColorSelected(color)
            onClosed: root.closeColorPicker()
        }
    }
}
