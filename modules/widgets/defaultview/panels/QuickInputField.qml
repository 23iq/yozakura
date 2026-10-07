import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.services
import "../../../services/timers/TimerFormat.js" as TimerFormat
import "../../../services/timers/QuickInput.js" as QuickInput

// One-line quick input of the timers hub with a live preview:
//   timer mode: "10m tea", "1h30", "25", "sw", "pomo 50 10", "18:00 call
//   mom", "in 20m stretch" (timers.parse while typing, timers.quick on
//   Enter), "focus 50" (focus mode), "note <text>" (quick note);
//   note mode: the line goes to the notes inbox.
// `done()` after a successful Enter (the hub closes).
Item {
    id: field

    property string mode: "timer"
    property real unit: 4
    property alias text: input.text

    signal done

    readonly property var intent: QuickInput.classify(input.text, field.mode)
    // Backend parse result for the current text (timer mode)
    property var parsed: null
    property string parseError: ""
    property string submitError: ""
    property string parsedText: ""

    readonly property var preview: {
        const c = field.intent;
        if (c.kind === "focus")
            return c.valid ? {
                "icon": Icons.brain,
                "text": FocusMode.active && c.minutes === 0 ? I18n.t("focus.stop") : I18n.t("focus.start_for", c.minutes > 0 ? c.minutes : FocusMode.defaultMinutes)
            } : null;
        if (c.kind === "note")
            return {
                "icon": Icons.notePencil,
                "text": I18n.t("quicknote.add_to", QuickNote.title)
            };
        if (c.kind === "timers" && field.parsed && field.parsedText === c.text) {
            const p = TimerFormat.preview(field.parsed, I18n.t, TimersService.use12h);
            return p ? {
                "icon": Icons[p.icon] || Icons.timer,
                "text": p.text
            } : null;
        }
        return null;
    }
    readonly property string error: field.submitError !== "" ? field.submitError : (field.intent.kind === "timers" && field.parsedText === field.intent.text && !field.parsed ? field.parseError : (field.intent.kind === "focus" && !field.intent.valid ? I18n.t("timers.input.invalid") : ""))
    readonly property string hint: field.mode === "note" ? I18n.t("quicknote.hint") : I18n.t("timers.input.hint")

    implicitHeight: box.height + Space.s + previewRow.implicitHeight

    function focusInput() {
        input.forceActiveFocus();
    }

    Timer {
        id: debounce
        interval: 120
        onTriggered: {
            const c = QuickInput.classify(input.text, field.mode);
            const q = c.kind === "timers" ? c.text : "";
            if (q === "")
                return;
            TimersService.parse(q, (intent, error) => {
                if (QuickInput.classify(input.text, field.mode).text !== q)
                    return;
                field.parsedText = q;
                field.parsed = intent;
                field.parseError = error || "";
            });
        }
    }

    function submit() {
        const c = field.intent;
        field.submitError = "";
        if (c.kind === "empty")
            return;
        if (c.kind === "focus") {
            if (!c.valid)
                return;
            if (FocusMode.active && c.minutes === 0)
                FocusMode.stop(false);
            else
                FocusMode.start(c.minutes);
            field.finish();
            return;
        }
        if (c.kind === "note") {
            if (QuickNote.add(c.text))
                field.finish();
            return;
        }
        const q = c.text;
        TimersService.quick(q, (result, error) => {
            if (error) {
                field.submitError = error.message || String(error);
                return;
            }
            field.finish();
        });
    }

    function finish() {
        input.text = "";
        field.done();
    }

    // The language's control box (a hairline while focused)
    StyledRect {
        id: box
        variant: "common"
        width: parent.width
        height: Space.controlM
        radius: Look.chipRadius(height)
        enableBorder: input.activeFocus

        // Languages without control boxes (ink): a hairline under the field
        Divider {
            anchors.bottom: parent.bottom
            width: parent.width
            visible: Look.dividers && !Look.boxedControls
        }

        Text {
            id: glyph
            anchors.left: parent.left
            anchors.leftMargin: Space.m
            anchors.verticalCenter: parent.verticalCenter
            text: field.mode === "note" ? Icons.notePencil : Icons.timer
            font.family: Icons.font
            font.pixelSize: Type.iconSize("body")
            color: Type.muted
        }

        TextInput {
            id: input
            objectName: "quickInput"
            anchors.left: glyph.right
            anchors.leftMargin: Space.s
            anchors.right: parent.right
            anchors.rightMargin: Space.m
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            color: Type.text
            selectionColor: Type.accent
            selectedTextColor: Type.accentInk
            font.family: Type.family("body")
            font.pixelSize: Type.size("body")
            // Classified here: the `intent` binding may not have caught up yet
            onTextChanged: {
                field.submitError = "";
                if (QuickInput.classify(input.text, field.mode).kind === "timers")
                    debounce.restart();
            }
            Keys.onReturnPressed: event => {
                field.submit();
                event.accepted = true;
            }
            Keys.onEnterPressed: event => {
                field.submit();
                event.accepted = true;
            }

            KitText {
                anchors.fill: parent
                visible: input.text === ""
                role: "body"
                color: Type.muted
                text: field.hint
            }
        }
    }

    Row {
        id: previewRow
        objectName: "quickPreview"
        anchors.top: box.bottom
        anchors.topMargin: Space.s
        x: Space.m
        width: parent.width - x
        spacing: Space.s
        readonly property bool shown: field.preview !== null || field.error !== ""

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: field.error !== "" ? Icons.warning : (field.preview ? field.preview.icon : Icons.info)
            font.family: Icons.font
            font.pixelSize: Type.iconSize("caption")
            color: field.error !== "" ? Colors.error : (field.preview ? Type.accent : Type.muted)
        }
        KitText {
            objectName: "quickPreviewText"
            anchors.verticalCenter: parent.verticalCenter
            width: previewRow.width - Type.iconSize("caption") - previewRow.spacing
            role: field.preview && field.error === "" ? "secondary" : "caption"
            color: field.error !== "" ? Colors.error : (field.preview ? Type.text : Type.muted)
            text: field.error !== "" ? field.error : (field.preview ? field.preview.text : I18n.t("timers.input.examples"))
        }
    }
}
