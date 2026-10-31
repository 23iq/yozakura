import QtQuick
import qs.modules.theme

// Pointer source of the cursor lantern (theme.lighting.lantern) for one
// surface host: declare it inside an Item that contains the host's
// surfaces (a parent HoverHandler sees the pointer even over children that
// take hover themselves). LanternGlow finds the nearest one among its
// ancestors. Disabled, so free, while the lantern is off.
HoverHandler {
    objectName: "lanternScope"
    enabled: Lighting.lanternOn
}
