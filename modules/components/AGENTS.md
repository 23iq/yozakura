# COMPONENTS KNOWLEDGE BASE

## OVERVIEW
Atomic design library for the Yozakura shell. 26 QML components + 29 GLSL shaders (`.frag`/`.vert`/`.qsb`). Every themed container in the shell ultimately uses `StyledRect`. Shader-driven UI for gradients, wavy animations, and panel blur effects.

## STRUCTURE
### Layout & Containers
| Component | Role |
|-----------|------|
| `StyledRect.qml` | **THE** base container. 300+ usages. `variant` prop selects style from `Styling.qml` |
| `Separator.qml` | Visual divider between sections |
| `ActionGrid.qml` | Flexible button grid (row or grid layout). Used by PowerMenu, ToolsMenu |

### Input
| Component | Role |
|-----------|------|
| `SearchInput.qml` | Text entry with icon, prefix, escape-to-clear |
| `StyledSlider.qml` | Standard slider (volume, brightness, progress) |
| `PositionSlider.qml` | Media position/seek slider |
| `CircularControl.qml` | Circular knob for volume/mic |
| `ToggleButton.qml` | Icon button with tooltip and toggle state |

### Display & Feedback
| Component | Role |
|-----------|------|
| `StyledToolTip.qml` | Themed tooltip |
| `BarPopup.qml` | Base for all bar/notch flyout popups. Requires `anchorItem` + `bar` ref |
| `ContextMenu.qml` | Right-click context menu |
| `OptionsMenu.qml` | Dropdown option selector |

### Animation & Visuals
| Component | Role |
|-----------|------|
| `WavyLine.qml` | Signature animated progress line (custom shader) |
| `CarouselProgress.qml` | Step-based progress dots |
| `DiagonalStripePattern.qml` | Decorative pattern overlay |
| `BgShadow.qml` / `Shadow.qml` | Drop shadow effects |
| `Outline.qml` | Border outline effect |
| `Tinted.qml` / `TintedWallpaper.qml` | Color tint overlays |

### Utility & Core
| Component | Role |
|-----------|------|
| `GradientCache.qml` | **Singleton**. Shares GPU gradient textures across `StyledRect` instances |
| `GradientCanvas.qml` | Canvas-based gradient renderer |

## SURFACE EFFECTS (`surfaceeffects/`)
`theme.surfaceEffect` (`none` | `crt` | `ink`) + `theme.surfaceEffectOptions`.
`SurfaceEffects.js` is the registry (one component file + one entry per
effect; options, worst-case overlay alphas), `SurfaceFx.qml` the resolved
singleton (legibility clamp: `safeStrength` keeps surface text at WCAG AA).
`StyledRect` has one extra Loader: the effect's overlay on shell surfaces
(`effectSurface`, defaults to `glassSurface`; bar module pills set `"bar"`)
or its highlight fill on `highlightVariants` (`effectHighlight: false`
opts out). Inactive with `none`. Shaders are static (no time uniform);
`BrushStroke.qml` is shared with the "brush" workspace indicator.
Tests: `tests/surface-effects.test.{cjs,py}`; renders:
`tools/render/panels_render.py` with `"theme": {"surfaceEffect": ...}`.

## CONVENTIONS
- **StyledRect variants**: Always pass `variant` as one of: `"pane"`, `"popup"`, `"common"`, `"internalbg"`, `"focus"`. Variant config comes from `Styling.getStyledRectConfig()`.
- **Property aliasing**: Components expose internal state via `property alias` for clean external APIs.
- **Reactive styling**: All components use `Config.resolveColor()` and `Styling.radius()`. Changing a JSON preset updates the entire library instantly.
- **BarPopup pattern**: Flyouts require an `anchorItem` and `bar` reference to anchor correctly to the shell panel.
- **Shader binaries**: `.qsb` files are pre-compiled shaders. Regenerate with `qsb` tool if `.frag`/`.vert` sources change.

## ANTI-PATTERNS
- Using raw `Rectangle` instead of `StyledRect` for any container.
- Hardcoding colors, radii, or font sizes instead of using `Colors.*`, `Styling.radius()`, `Styling.fontSize()`.
- Creating popups without the `anchorItem`/`bar` reference pattern from `BarPopup`.
