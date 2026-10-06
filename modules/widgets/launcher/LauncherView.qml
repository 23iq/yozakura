import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.modules.theme
import qs.modules.globals
import qs.config
import "Providers.js" as Providers
import "../dashboard/clipboard"
import "../dashboard/emoji"
import "../dashboard/tmux"
import "../dashboard/notes"

// The launcher (notch module "launcher"): tab 0 is the provider search
// (LauncherSearch: apps, calculator, commands, files, AI...), tabs 1-4 are
// the prefix tabs (clipboard, emoji, tmux, notes) loaded on demand. Typing
// exactly "<tab prefix> " switches to that tab; Backspace on its empty
// search comes back with the prefix typed.
Item {
    id: root

    readonly property bool isCompact: currentTab === 0 || currentTab === 2
    // compactWhenEmpty: only the search field until the first keystroke
    readonly property bool bare: Config.layout.launcher.compactWhenEmpty && currentTab === 0 && searchText.length === 0
    readonly property bool previewing: currentTab === 0 && searchView.previewOpen
    implicitWidth: !bare && (!isCompact || previewing) ? Metrics.launcherWideW : Metrics.launcherCompactW
    implicitHeight: bare ? Metrics.rowHeight : isCompact && !previewing ? Metrics.launcherCompactH : Metrics.launcherWideH
    clip: bare || sizeMorph.running || heightMorph.running

    Behavior on implicitWidth {
        enabled: Motion.morph.duration > 0
        NumberAnimation {
            id: sizeMorph
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
    Behavior on implicitHeight {
        enabled: Motion.morph.duration > 0
        NumberAnimation {
            id: heightMorph
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }

    focus: true

    property int leftPanelWidth: isCompact ? Metrics.launcherCompactW : Metrics.launcherLeftPanelW
    property int currentTab: GlobalStates.widgetsTabCurrentIndex  // 0=search, 1=clip, 2=emoji, 3=tmux, 4=notes
    // Set after Backspace left a tab, until the prefix is edited away.
    property bool prefixDisabled: false
    readonly property string searchText: GlobalStates.launcherSearchText

    onCurrentTabChanged: {
        GlobalStates.widgetsTabCurrentIndex = currentTab;
        focusSearchInput();
    }

    onActiveFocusChanged: {
        if (activeFocus)
            focusSearchInput();
    }

    Component.onCompleted: focusSearchInput()

    function prefixes() {
        const out = {};
        Providers.PROVIDERS.forEach(p => {
            if (p.prefix)
                out[p.prefix] = Config.prefix[p.prefix] || "";
        });
        return out;
    }

    function detectPrefix(text) {
        const pre = prefixes();
        if (prefixDisabled) {
            // Re-enable once the prefix is gone.
            if (!Providers.startsWithTabPrefix(text, pre))
                prefixDisabled = false;
            return 0;
        }
        return Providers.detectTab(text, pre, Config.prefix.launcher.disabled);
    }

    function tabLoader(index) {
        return internalStack.itemAt(index - 1);
    }

    // Leaves a tab for the search with its prefix typed (Backspace on empty).
    function leaveTab(index) {
        const p = Providers.tabProvider(index);
        prefixDisabled = true;
        currentTab = 0;
        GlobalStates.launcherSearchText = p ? (Config.prefix[p.prefix] || "") + " " : "";
        focusSearchInput();
    }

    onSearchTextChanged: {
        const tab = detectPrefix(searchText);
        if (tab === currentTab)
            return;
        if (tab === 0) {
            if (currentTab !== 0) {
                currentTab = 0;
                prefixDisabled = false;
            }
            return;
        }
        currentTab = tab;
        Qt.callLater(() => {
            const loader = root.tabLoader(tab);
            if (loader && loader.item) {
                if (loader.item.searchText !== undefined)
                    loader.item.searchText = "";
                root.focusSearchInput();
            }
        });
    }

    // Focus retries: tabs load lazily, the notch animates in.
    Timer {
        id: focusRetryTimer
        interval: 50
        repeat: true
        property int retries: 0
        onTriggered: {
            if (retries++ > 10) {
                running = false;
                return;
            }
            let target = null;
            if (root.currentTab === 0)
                target = searchView;
            else {
                const loader = root.tabLoader(root.currentTab);
                target = loader ? loader.item : null;
            }
            if (target && target.focusSearchInput) {
                target.focusSearchInput();
                running = false;
            }
        }
    }

    function focusSearchInput() {
        focusRetryTimer.retries = 0;
        focusRetryTimer.start();
    }

    LauncherSearch {
        id: searchView
        objectName: "launcherSearch"
        anchors.fill: parent
        visible: root.currentTab === 0
    }

    // Prefix tabs (clipboard, emoji, tmux, notes)
    StackLayout {
        id: internalStack
        anchors.fill: parent
        visible: root.currentTab !== 0
        currentIndex: root.currentTab - 1

        Loader {
            id: clipboardLoader
            active: root.currentTab === 1 || item !== null
            sourceComponent: Component {
                ClipboardTab {
                    leftPanelWidth: root.leftPanelWidth
                    prefixIcon: Icons.clipboard
                    onBackspaceOnEmpty: root.leaveTab(1)
                    onRequestOpenItem: (itemId, items, currentContent, filePathGetter, urlChecker) => {
                        root.openItemInternal(itemId, items, currentContent, filePathGetter, urlChecker);
                    }
                }
            }
            onLoaded: {
                if (root.currentTab === 1)
                    root.focusSearchInput();
            }
        }

        Loader {
            id: emojiLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: root.currentTab === 2 || item !== null
            sourceComponent: Component {
                EmojiTab {
                    anchors.fill: parent
                    leftPanelWidth: root.width
                    prefixIcon: Icons.emoji
                    onBackspaceOnEmpty: root.leaveTab(2)
                }
            }
            onLoaded: {
                if (root.currentTab === 2)
                    root.focusSearchInput();
            }
        }

        Loader {
            id: tmuxLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: root.currentTab === 3 || item !== null
            sourceComponent: Component {
                TmuxTab {
                    leftPanelWidth: root.leftPanelWidth
                    prefixIcon: Icons.terminal
                    onBackspaceOnEmpty: root.leaveTab(3)
                }
            }
            onLoaded: {
                if (root.currentTab === 3)
                    root.focusSearchInput();
            }
        }

        Loader {
            id: notesLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: root.currentTab === 4 || item !== null
            sourceComponent: Component {
                NotesTab {
                    anchors.fill: parent
                    leftPanelWidth: root.leftPanelWidth
                    prefixIcon: Icons.note
                    onBackspaceOnEmpty: root.leaveTab(4)
                }
            }
            onLoaded: {
                if (root.currentTab === 4)
                    root.focusSearchInput();
            }
        }
    }

    // Opens a clipboard entry (file, image or URL) with the default app.
    Process {
        id: openProcess
    }

    function openItemInternal(itemId, items, currentContent, getFilePathFromUri, isUrl) {
        for (let i = 0; i < items.length; i++) {
            if (items[i].id !== itemId)
                continue;
            const item = items[i];
            const content = currentContent || item.preview;
            let target = "";
            if (item.isFile)
                target = getFilePathFromUri(content);
            else if (item.isImage && item.binaryPath)
                target = item.binaryPath;
            else if (isUrl(content))
                target = content.trim();
            if (target) {
                openProcess.command = ["xdg-open", target];
                openProcess.running = true;
            }
            return;
        }
    }
}
