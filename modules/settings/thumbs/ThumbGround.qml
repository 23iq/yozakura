import QtQuick
import qs.modules.components.kit

// The plain ground of a card picture that is not about the desktop: the
// raised fill, rounded like the card's preview area; the option's object is
// drawn on it (thumbs that once drew a fake wallpaper behind it).
Mark {
    radius: Space.smallRadius
    color: Look.raisedFill(false)
    clip: true
}
