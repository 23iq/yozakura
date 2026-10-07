import QtQuick
import Quickshell.Io
import qs.modules.components.kit
import qs.modules.globals
import qs.modules.services
import "EmojiModel.js" as EmojiModel

// Emoji picker tab (launcher prefix): the kit SearchField, then one list:
// the recent strip (row 0 while not searching, Left/Right move in it) and
// the emoji rows; Shift+Enter / click on an emoji with skin tones opens its
// tone options. State and actions live here; EmojiSearch (keys), EmojiList,
// EmojiRecentStrip and EmojiRow draw it; pure helpers in EmojiModel.js.
Item {
    id: root
    focus: true

    property string prefixIcon: ""
    signal backspaceOnEmpty

    property int leftPanelWidth: 0

    property string searchText: ""
    property int selectedIndex: -1
    property int selectedRecentIndex: -1
    property var recentEmojis: []
    property var emojiData: []
    readonly property var skinTones: EmojiModel.SKIN_TONES
    readonly property bool isAtRecent: selectedIndex === 0 && hasRecentRow
    readonly property bool hasRecentRow: emojisModel.count > 0 && emojisModel.get(0).isRecentContainer

    // Tone options of an emoji row
    property int expandedItemIndex: -1
    property int selectedOptionIndex: 0
    property bool keyboardNavigation: false
    // "Clear" on the recent label asks once more before clearing
    property bool clearButtonConfirmState: false

    readonly property alias model: emojisModel
    readonly property alias recentModel: recentModel

    implicitWidth: 464
    implicitHeight: 296

    ListModel {
        id: emojisModel
    }
    ListModel {
        id: recentModel
    }

    function collapseOptions() {
        expandedItemIndex = -1;
        selectedOptionIndex = 0;
        keyboardNavigation = false;
    }

    function toggleOptions(index, byKeyboard) {
        if (expandedItemIndex === index) {
            collapseOptions();
        } else {
            expandedItemIndex = index;
            selectedOptionIndex = 0;
            keyboardNavigation = byKeyboard;
        }
    }

    onSelectedIndexChanged: {
        if (expandedItemIndex >= 0 && selectedIndex !== expandedItemIndex)
            collapseOptions();
        if (selectedIndex !== 0 || !hasRecentRow)
            selectedRecentIndex = -1;
        else if (selectedRecentIndex === -1 && recentEmojis.length > 0)
            selectedRecentIndex = 0;
    }

    onSearchTextChanged: {
        clearButtonConfirmState = false;
        performSearch();
    }

    function setRows(list, withRecent) {
        emojisModel.clear();
        if (withRecent)
            emojisModel.append({
                emojiData: {},
                isRecentContainer: true
            });
        for (var i = 0; i < list.length; i++)
            emojisModel.append({
                emojiData: list[i],
                isRecentContainer: false
            });
    }

    function clearSearch() {
        searchText = "";
        selectedIndex = -1;
        selectedRecentIndex = -1;
        focusSearchInput();
        loadInitialEmojis();
        list.scrollToTop();
    }

    function clearRecentEmojis() {
        recentEmojis = [];
        saveRecentEmojis();
        updateRecentModel();
        loadInitialEmojis();
        clearButtonConfirmState = false;
        focusSearchInput();
    }

    function focusSearchInput() {
        search.focusInput();
    }

    function performSearch() {
        if (searchText.length === 0) {
            loadInitialEmojis();
            selectedIndex = -1;
            selectedRecentIndex = -1;
            list.scrollToTop();
            return;
        }
        const found = EmojiModel.filter(emojiData, searchText);
        setRows(found, false);
        if (found.length > 0)
            selectedIndex = 0;
    }

    function updateRecentModel() {
        recentModel.clear();
        for (var i = 0; i < recentEmojis.length; i++)
            recentModel.append({
                emojiData: recentEmojis[i]
            });
    }

    function loadInitialEmojis() {
        setRows(EmojiModel.initial(emojiData), recentEmojis.length > 0 && searchText === "");
    }

    function saveRecentEmojis() {
        saveProcess.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1"', "emoji-save", Brand.cacheDir + "/emojis.json", JSON.stringify(recentEmojis, null, 2)];
        saveProcess.running = true;
    }

    function copyEmoji(emoji, skinToneModifier) {
        const entry = EmojiModel.recentEntry(emoji, skinToneModifier || "");
        recentEmojis = EmojiModel.addRecent(recentEmojis, entry, Date.now());
        updateRecentModel();
        saveRecentEmojis();
        Visibilities.setActiveModule("");
        ClipboardService.copyAndTypeEmoji(entry.emoji);
    }

    // Enter: the tone under the cursor, the recent emoji, or the row.
    function activate() {
        if (expandedItemIndex >= 0) {
            const tone = skinTones[selectedOptionIndex];
            if (tone)
                copyEmoji(emojisModel.get(expandedItemIndex).emojiData, tone.modifier);
        } else if (isAtRecent) {
            if (selectedRecentIndex >= 0 && selectedRecentIndex < recentEmojis.length)
                copyEmoji(recentEmojis[selectedRecentIndex]);
        } else if (selectedIndex >= 0 && selectedIndex < emojisModel.count) {
            copyEmoji(emojisModel.get(selectedIndex).emojiData);
        }
    }

    function onDownPressed() {
        if (expandedItemIndex >= 0) {
            if (selectedOptionIndex < skinTones.length - 1) {
                selectedOptionIndex++;
                keyboardNavigation = true;
            }
        } else if (selectedIndex < emojisModel.count - 1) {
            selectedIndex++;
        }
    }

    function onUpPressed() {
        if (expandedItemIndex >= 0) {
            if (selectedOptionIndex > 0) {
                selectedOptionIndex--;
                keyboardNavigation = true;
            }
        } else if (selectedIndex > 0) {
            selectedIndex--;
        } else {
            selectedIndex = -1;
        }
    }

    function onLeftPressed() {
        if (isAtRecent && selectedRecentIndex > 0)
            selectedRecentIndex--;
    }

    function onRightPressed() {
        if (isAtRecent && selectedRecentIndex < recentEmojis.length - 1)
            selectedRecentIndex++;
    }

    EmojiSearch {
        id: search
        tab: root
        width: parent.width
        anchors.top: parent.top
    }

    EmojiList {
        id: list
        tab: root
        width: parent.width
        anchors.top: search.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Space.s
    }

    Process {
        id: emojiProcess
        command: ["cat", "--", Qt.resolvedUrl("../../../../assets/emojis.json").toString().replace("file://", "")]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.emojiData = EmojiModel.parseTable(text);
                root.loadInitialEmojis();
            }
        }
    }

    Process {
        id: recentProcess
        command: ["sh", "-c", 'cat "$1" 2>/dev/null || echo "[]"', "emoji-recent", Brand.cacheDir + "/emojis.json"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.recentEmojis = EmojiModel.parseRecent(text);
                root.updateRecentModel();
                if (root.searchText === "")
                    root.loadInitialEmojis();
            }
        }
    }

    Process {
        id: saveProcess
    }

    Component.onCompleted: {
        emojiProcess.running = true;
        recentProcess.running = true;
        Qt.callLater(() => focusSearchInput());
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.focusSearchInput()
    }
}
