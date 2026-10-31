import QtQuick
import qs.modules.theme

// A forced weather for the surfaces inside one item (the settings preview):
// declare it in an Item that contains StyledRect surface roots; their
// weather overlay draws `condition` (a WeatherFxModel.PREVIEWS id) at the
// configured mode instead of the live weather. Overlays load while any
// scope exists, so it works with theme.weatherFx.mode off. Runtime only:
// nothing is stored.
QtObject {
    id: root

    objectName: "weatherFxScope"
    property string condition: "rain"
    readonly property var effects: WeatherFx.effectsFor(root.condition)

    Component.onCompleted: WeatherFx.scopes += 1
    Component.onDestruction: WeatherFx.scopes -= 1
}
