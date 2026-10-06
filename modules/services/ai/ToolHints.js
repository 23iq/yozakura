.pragma library

// Capability hints appended to an Assistant chat's system prompt when the
// model gets the Yozakura tools: the user's own prompt (ai.systemPrompt)
// stays as written, the hints only name what the tools can do so the
// model reaches for timers, keybinds, routines, notes... instead of
// answering "I can't". Tested in tests/ai-tool-media.test.cjs.

var HINTS = [
    { tools: ["timer_start"], text: "Timers, reminders, the stopwatch and focus mode: timer_start, reminder_add, stopwatch_control, focus_start, focus_status." },
    { tools: ["binds_search"], text: "Keybinds: find an action with binds_search, check a combo with binds_check, propose free combos with binds_suggest; call binds_set only after the user agrees (they confirm it). Every edit returns an undo." },
    { tools: ["routine_save"], text: "Routines: routine_save bundles several steps (bind actions, tools, delays) into one command — use it when the user says \"save this as a routine\" or wants one key to do several things; bind it with binds_set (action utilities.routine) and run it with routine_run." },
    { tools: ["notes_search"], text: "Notes: notes_search, notes_read, notes_create, notes_append (the shell's Notes tab)." },
    { tools: ["apps_find"], text: "Apps: apps_find, app_launch (optionally on a workspace), app_close (ask first)." },
    { tools: ["system_info"], text: "Status: system_info (battery, CPU, RAM, disks, temperatures), network_status, bluetooth_status; settings: wifi_toggle, wifi_connect, bluetooth_connect, audio_output_set, brightness_set, nightlight_set, caffeine_set." },
    { tools: ["screen_look"], text: "screen_look shows you the screen when the user asks about what is on it." }
];

// tools: [{tool, server}] as given to the session (McpBridge.toolsFor).
function hints(tools) {
    var have = {};
    (tools || []).forEach(function (t) {
        if (t && t.server === "yozakura")
            have[t.tool] = true;
    });
    var out = [];
    HINTS.forEach(function (h) {
        if (h.tools.some(function (n) {
            return have[n];
        }))
            out.push("- " + h.text);
    });
    return out;
}

// The system prompt with the hints (unchanged when no tool matches).
function withHints(system, tools) {
    var h = hints(tools);
    var base = String(system || "").trim();
    if (!h.length)
        return base;
    var block = "Desktop tools you have:\n" + h.join("\n") + "\nResults with \"undo\" can be reverted by the user; mention it briefly.";
    return base ? base + "\n\n" + block : block;
}
