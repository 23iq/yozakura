import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.components
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

    implicitHeight: box.height + field.unit * 2 + previewRow.implicitHeight

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

    StyledRect {
        id: box
        variant: "common"
        width: parent.width
        height: Math.round(Styling.fontSize(0) * 2.6)
        radius: Styling.radius(-2)
        enableBorder: input.activeFocus

        Text {
            id: glyph
            anchors.left: parent.left
            anchors.leftMargin: field.unit * 3
            anchors.verticalCenter: parent.verticalCenter
            text: field.mode === "note" ? Icons.notePencil : Icons.timer
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(1)
            color: Colors.primary
        }

        TextInput {
            id: input
            objectName: "quickInput"
            anchors.left: glyph.right
            anchors.leftMargin: field.unit * 2
            anchors.right: parent.right
            anchors.rightMargin: field.unit * 3
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            color: Colors.overBackground
            selectionColor: Colors.primary
            selectedTextColor: Colors.overPrimary
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
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

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: input.text === ""
                text: field.hint
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Colors.outline
                font: input.font
            }
        }
    }

    Row {
        id: previewRow
        objectName: "quickPreview"
        anchors.top: box.bottom
        anchors.topMargin: field.unit * 2
        x: field.unit * 3
        width: parent.width - x
        spacing: field.unit * 2
        readonly property bool shown: field.preview !== null || field.error !== ""
        opacity: shown ? 1 : 0.6

        Text {
            text: field.error !== "" ? Icons.warning : (field.preview ? field.preview.icon : Icons.info)
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(-1)
            color: field.error !== "" ? Colors.error : Colors.primary
        }
        Text {
            objectName: "quickPreviewText"
            width: previewRow.width - Styling.fontSize(-1) - previewRow.spacing
            text: field.error !== "" ? field.error : (field.preview ? field.preview.text : I18n.t("timers.input.examples"))
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: field.error !== "" ? Colors.error : (field.preview ? Colors.overBackground : Colors.overSurfaceVariant)
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
        }
    }
}
