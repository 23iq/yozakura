.pragma library

var data = {
    // Off: the notch only appears while it shows a view (launcher, power
    // menu...); its activities move to the bar or corner pills
    // (modules/shell/LayoutModel.js)
    "enabled": true,
    "position": "top",
    // start | center | end along the edge (modules/shell/EdgeLayout.js)
    "align": "center",
    "hoverRegionHeight": 8,
    "keepHidden": false,
    "noMediaDisplay": "userHost",
    "customText": "Yozakura",
    "disableHoverExpansion": true,
    "hoverExpandDelay": 90,
    "hoverCollapseDelay": 200,
    "expandOn": "hover",
    "expandedMediaWidth": 440,
    "mediaAnimationDuration": 160,
    "expandedArtworkSize": 64,
    "microphoneNoticeDuration": 1800,
    "visualizer": true,
    // attached | island | pill (modules/notch/styles/NotchStyles.js);
    // activities: order/side/enabled of the island's activities
    // ({id, side, enabled}, modules/widgets/defaultview/activities/ActivityRegistry.js).
    "style": "attached",
    "activities": [],
    "osd": false
}
