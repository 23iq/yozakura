.pragma library
.import "../../widgets/defaultview/activities/ActivityRegistry.js" as Registry
.import "../../widgets/defaultview/panels/NotchPanels.js" as NotchPanels

// Live activities as chips in the bar (ActivityService.presentation "bar",
// notch.activitiesIn): which chips show, which notch panel a chip opens in
// its popup, and the hover/pin rules of that popup. Pure, unit tested in
// tests/activity-chips.test.cjs.

// Activities split into the chips shown (at most `max`, ActivityService
// order) and how many more hide behind a "+N" chip.
function chips(activities, max) {
    var list = [];
    var src = activities || [];
    for (var i = 0; i < src.length; i++)
        if (src[i])
            list.push(src[i]);
    var n = Math.max(1, max || 1);
    if (list.length <= n)
        return { shown: list, overflow: 0 };
    // The "+N" chip takes the last slot
    var keep = Math.max(1, n - 1);
    return { shown: list.slice(0, keep), overflow: list.length - keep };
}

// Availability context of the notch panels (NotchPanels.availability) from
// the service's lists; the notch's own header is off while chips show.
function context(service) {
    var s = service || {};
    var tasks = s.tasks || [];
    var timers = 0;
    for (var i = 0; i < tasks.length; i++)
        if (tasks[i] && tasks[i].source === "timers")
            timers++;
    return {
        transfers: (s.transfers || []).length,
        timers: timers,
        privacy: (s.privacy || []).length
    };
}

// Panel id a chip opens ("" when none or unavailable): the panel of the
// activity's registry trigger (notch.activities), as in the notch header.
function panelFor(activity, resolved, available) {
    if (!activity)
        return "";
    var id = NotchPanels.panelFor(Registry.triggerOf(activity, resolved));
    if (id === "" || NotchPanels.isAuto(id))
        return "";
    return available && available[id] ? id : "";
}

// Label of a chip: shown when it fits the room the bar gives it (a vertical
// bar only fits a short one).
function showLabel(activity, labelWidth, room) {
    if (!activity || !activity.label)
        return false;
    return labelWidth <= room + 0.5;
}

// Click on a chip: pins its popup, or unpins (closes) the one pinned.
// state: { chip, pinned } -> new state
function clicked(state, chip) {
    var s = state || {};
    if (s.pinned && s.chip === chip)
        return { chip: "", pinned: false };
    return { chip: chip, pinned: true };
}

// The popup stays while pinned or while the pointer is on a chip or in
// the popup (the collapse delay bridges the gap between them).
function held(pinned, chipHovered, popupHovered) {
    return !!(pinned || chipHovered || popupHovered);
}
