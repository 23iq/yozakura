.pragma library

// Onboarding wizard steps, in order. Adding a step = one Step<Name>.qml in
// this directory + one entry here (+ translations). `title`/`subtitle` are
// translation keys, `icon` an Icons property, `component` the file loaded
// for the step (it gets `wizard`, the OnboardingState). `hero: true` steps
// draw their own header (welcome, finish).
var STEPS = [
    { "id": "welcome", "component": "StepWelcome.qml", "icon": "seal", "title": "onboarding.welcome.title", "subtitle": "onboarding.welcome.subtitle", "optional": false, "hero": true },
    { "id": "preset", "component": "StepPreset.qml", "icon": "magicWand", "title": "onboarding.preset.title", "subtitle": "onboarding.preset.subtitle", "optional": true },
    { "id": "wallpaper", "component": "StepWallpaper.qml", "icon": "image", "title": "onboarding.wallpaper.title", "subtitle": "onboarding.wallpaper.subtitle", "optional": true },
    { "id": "system", "component": "StepSystem.qml", "icon": "terminal", "title": "onboarding.system.title", "subtitle": "onboarding.system.subtitle", "optional": true },
    { "id": "ai", "component": "StepAi.qml", "icon": "sparkle", "title": "onboarding.ai.title", "subtitle": "onboarding.ai.subtitle", "optional": true },
    { "id": "keybinds", "component": "StepKeybinds.qml", "icon": "keyboard", "title": "onboarding.keybinds.title", "subtitle": "onboarding.keybinds.subtitle", "optional": true },
    { "id": "specials", "component": "StepSpecials.qml", "icon": "cube", "title": "onboarding.specials.title", "subtitle": "onboarding.specials.subtitle", "optional": true },
    { "id": "finish", "component": "StepFinish.qml", "icon": "checkCircle", "title": "onboarding.finish.title", "subtitle": "onboarding.finish.subtitle", "optional": false, "hero": true }
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
