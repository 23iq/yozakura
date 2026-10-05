.pragma library
.import "profiles/smooth.js" as Smooth
.import "profiles/springs.js" as Springs
.import "profiles/snappy.js" as Snappy
.import "profiles/gentle.js" as Gentle
.import "profiles/stepped.js" as Stepped
.import "profiles/sakura.js" as Sakura
.import "profiles/off.js" as Off

// Motion profiles: named sets of compositor animations (Hyprland curves +
// animation-tree leaves) plus the shell animation scale/easing family.
// Selected by `compositor.motionProfile`, resolved by MotionSpec.js and
// rendered into the generated Hyprland config (CompositorMotion.qml ->
// backend compositor service) and Config.animDuration.
//
// Adding a profile = one file in profiles/ + one entry in ORDER (+ its
// prefs.motion.profile.<id>[.desc] translations).
//
// Profile format:
//   id, label, description, icon     identity (label/description = i18n keys)
//   disabled                         true = animations off (compositor + shell)
//   curves {name: curve}             names start with the profile id
//     {type: "bezier", points: [x0, y0, x1, y1]}
//     {type: "spring", mass, stiffness, dampening, fallback: [x0, y0, x1, y1]}
//       (fallback = bezier used where springs are unsupported: hyprland.conf)
//   leaves {node: {curve, speed, style, enabled}}
//     node = a Hyprland animation-tree node (MotionSpec.TREE); nodes not
//     listed inherit from their parent, like Hyprland does. speed is in
//     Hyprland units (1 = 100 ms); style e.g. "popin 80%", "slidefade 20%".
//   borderLoop {enabled, speed, curve}   looping gradient rotation (borderangle)
//   shell {scale, easing}            Config.animDuration multiplier and the
//                                    Qt easing family name (Config.animEasing)

var ORDER = [Smooth.profile, Springs.profile, Snappy.profile, Gentle.profile, Stepped.profile, Sakura.profile, Off.profile];

var DEFAULT_ID = "smooth";

function all() {
    return ORDER.slice();
}

function ids() {
    return ORDER.map(function (p) {
        return p.id;
    });
}

function get(id) {
    for (var i = 0; i < ORDER.length; i++) {
        if (ORDER[i].id === id)
            return ORDER[i];
    }
    return null;
}

// The profile for an id, falling back to the default for unknown ids.
function resolveId(id) {
    return get(id) || get(DEFAULT_ID);
}
