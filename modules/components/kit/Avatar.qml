import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// A circular Art: a person or a source (notification app, contact). With
// no image, shows the initials of `name` (or the `icon` glyph).
Art {
    id: root

    property string name: ""

    icon: Icons.user
    radius: Math.min(width, height) / 2
    placeholderText: {
        const parts = root.name.trim().split(/\s+/).filter(p => p.length > 0);
        if (parts.length === 0)
            return "";
        return String(parts[0][0] + (parts.length > 1 ? parts[parts.length - 1][0] : "")).toUpperCase();
    }
}
