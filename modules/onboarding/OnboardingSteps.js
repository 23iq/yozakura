.pragma library

// Onboarding wizard steps, in order. Adding a step = one Step<Name>.qml in
// this directory + one entry here (+ translations). `title`/`subtitle` are
// translation keys, `icon` an Icons property, `component` the file loaded
// for the step (it gets `wizard`, the OnboardingState). `hero: true` steps
// draw their own header (welcome, finish).
var STEPS = [
    { "id": "welcome", "component": "StepWelcome.qml", "icon": "seal", "title": "onboarding.welcome.title", "subtitle": "onboarding.welcome.subtitle", "hero": true },
    { "id": "displays", "component": "StepDisplays.qml", "icon": "monitor", "title": "onboarding.displays.title", "subtitle": "onboarding.displays.subtitle" },
    { "id": "look", "component": "StepLook.qml", "icon": "palette", "title": "onboarding.look.title", "subtitle": "onboarding.look.subtitle" },
    { "id": "terminal", "component": "StepTerminal.qml", "icon": "terminal", "title": "onboarding.terminal.title", "subtitle": "onboarding.terminal.subtitle" },
    { "id": "apps", "component": "StepApps.qml", "icon": "squaresFour", "title": "onboarding.apps.title", "subtitle": "onboarding.apps.subtitle" },
    { "id": "ai", "component": "StepAi.qml", "icon": "sparkle", "title": "onboarding.ai.title", "subtitle": "onboarding.ai.subtitle" },
    { "id": "keybinds", "component": "StepKeybinds.qml", "icon": "keyboard", "title": "onboarding.keybinds.title", "subtitle": "onboarding.keybinds.subtitle" },
    { "id": "finish", "component": "StepFinish.qml", "icon": "checkCircle", "title": "onboarding.finish.title", "subtitle": "onboarding.finish.subtitle", "hero": true }
];

function count() {
    return STEPS.length;
}

function at(index) {
    return STEPS[clamp(index)];
}

function indexOf(id) {
    for (var i = 0; i < STEPS.length; i++) {
        if (STEPS[i].id === id)
            return i;
    }
    return -1;
}

function clamp(index) {
    return Math.max(0, Math.min(STEPS.length - 1, index | 0));
}

function next(index) {
    return clamp(index + 1);
}

function prev(index) {
    return clamp(index - 1);
}

function isFirst(index) {
    return index <= 0;
}

function isLast(index) {
    return index >= STEPS.length - 1;
}
