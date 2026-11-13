# Looks, presets and personalisation

Every kind of control in Halcyon has named looks. You can pick one for a single element, set a default for the whole window, or choose a preset that sets many at once. Any look you don't choose stays as it was in 1.0, so turning on a new version changes nothing until you opt in.

```lua
-- One element
Section:Toggle({ Title = "Fly", Style = "Slim" })

-- Every element of a kind in this window
Halcyon:CreateWindow({ Title = "Hub", Styles = { Toggle = "Slim", Slider = "Thick", Section = "Accent" } })

-- A coordinated set
Halcyon:CreateWindow({ Title = "Hub", Preset = "Glass" })
```

An element's own `Style` wins over the window's `Styles`, and those win over a preset. A misspelt name falls back to the default look instead of erroring.

The example hub's **Looks** tab shows every look side by side, each with the line that opts into it. Its "Try a look" section rebuilds the hub in a preset or window look, so you can compare them before choosing.

## Presets

| Preset | What it sets |
| --- | --- |
| `Classic` | Halcyon's default look |
| `Minimal` | Soft corners, flat sections, Slim toggles, Thin sliders, Underline tab marker and inputs, no button effects |
| `Glass` | Round corners, glass window and sections, Large toggles, Pill tab marker, Soft buttons, Glow effect |
| `Neon` | Gradient window, accent-edged sections, Glow toggles, Thick sliders, Glow tab marker |
| `Compact` | Dense rows, soft corners, outlined sections, Square toggles, Thin sliders |

`Halcyon:AddPreset(name, options)` registers your own preset. `Halcyon:GetPresets()` lists the presets.

## Looks by kind

`Halcyon:GetStyles(kind)` lists a kind's looks, default first, and `Halcyon:GetStyles()` lists the kinds.

| Kind | Looks | Set on the window with |
| --- | --- | --- |
| `Toggle` | Switch, Large, Slim, Square, Labelled, Icon, Glow, Checkbox, Circle, Chip | `Styles.Toggle` |
| `Thumb` | Circle, Oval, Square | `ToggleThumb` |
| `Slider` | Line, Thin, Thick, Handle, Ticks, Bare, Block | `Styles.Slider` |
| `SliderTooltip` | Rounded, Sharp, Pill, Plain | `SliderTooltipStyle` |
| `Button` | Row, Filled, Outline, Danger, Soft, Ghost, Gradient, Success | `Styles.Button` (also each button's `Variant`) |
| `ButtonEffect` | Sweep, Ripple, Lift, Glow, Press, Fill, None | `ButtonEffect` |
| `Input` | Boxed, Underline, Filled, Pill | `Styles.Input` |
| `Dropdown` | Box, Minimal, Chips, Inline | `Styles.Dropdown` |
| `Keybind` | Chip, Keycap, Brackets | `Styles.Keybind` |
| `Label` | Plain, Info, Success, Warning, Danger, Note | each label's `Style` |
| `Section` | Card, Outlined, Flat, Glass, Accent, Inset, Header, Panel | `SectionStyle` |
| `TabIndicator` | Bar, Pill, Underline, Dot, Glow, Fill, Text | `TabIndicator` |
| `Header` | Bar, Tall, Wordmark, Sidebar | `HeaderStyle` |
| `Navigation` | Sidebar, Rail, Top, Dock | `TabStyle` |
| `Window` | Solid, Glass, Gradient, Image | `WindowStyle` |
| `Open` | Pop, Zoom, Rise, Drop, Slide, Unroll, None | `OpenAnimation` |
| `PageTransition` | Rise, Slide, None | `PageTransition` |
| `Controls` | Default, Mac | `TopbarControls` |
| `Minimize` | Topbar, Pill, Chip | `MinimizeStyle` |
| `Notification` | Default, Timer, Compact, Banner, Progress, Accent, Glass, Achievement, Snackbar, Island | each notice's `Style`, or `Notifications.Style` |
| `Tooltip` | Card, Plain, Follow | `Styles.Tooltip`, or the tooltip's `Style` |
| `TopbarImage` | Circle, Rounded, Square, Squircle, Ring, Badge | `TopbarImageStyle` |
| `UpdateLog` | Timeline, Cards, Compact | `UpdateLog.Style` |
| `Watermark` | Card, Pill, Accent, Minimal | the watermark's `Style` |
| `KeybindList` | Card, Glass, Minimal | the list's `Style` |
| `Stat` | Card, Plain | `Styles.Stat` |
| `Graph` | Line, Area, Bars | `Styles.Graph` |

`Panel` puts each of a section's rows on its own inset card. The `Text` tab marker colours the open tab's words and icon with no fill behind them. The header looks are described in [api.md](api.md#header-styles).

### Your own looks

A look is a table of the same fields the built-in ones use (see the comments at the top of each element's file). With a base look, only the fields you give change:

```lua
Halcyon:AddStyle("Toggle", "Wide", { width = 52 }, "Switch")
Halcyon:AddStyle("Section", "Warm", { stroke = "warning" }, "Card")
```

## Design settings

These go on `CreateWindow`, and players can change them from the Personalise section (see below).

| Option | Values | Effect |
| --- | --- | --- |
| `Radius` | Sharp, Soft, Default, Round | Scales every corner |
| `Density` | Compact, Default, Spacious | Row height and padding (touch rows never drop below 44 px) |
| `TextSize` | Default, Large, Larger | Scales every text size |
| `Transparency` | 0 to 0.6 | How much of the game shows through the window |
| `BackgroundImage`, `BackgroundImageTransparency` | asset id, 0 to 1 | A picture behind the window's contents |
| `AccentGradient` | `true` or a Color3 | Accent fills (slider and progress bars) run into a second colour |
| `SafeStatusColors` | `true` | Status colours that stay distinct for colour-blind players |
| `SidebarWidth` | 150 to 280 | Width of the sidebar |
| `SidebarToggle` | `true` | A top-bar button that folds the sidebar to its icon rail |
| `Snap` | `true` | A dragged window snaps to the screen edges and the centre line |
| `CommandPalette` | `true` | Ctrl+K opens a search over every tab and setting (`PaletteKey` changes the key) |
| `FocusRing` | `false` | Turns off the accent ring that shows gamepad and keyboard selection |

## Personalisation

`Window:SettingsTab({ Personalise = true, ThemeBuilder = true })` adds two sections:

- **Personalise** covers font, text size, corners, spacing, window transparency, notice position, gradient accent and colour-blind-friendly status colours. Changes apply live and are saved with the window's preferences. Pass a table instead of `true` to hide rows, for example `{ Font = false }`.
- **Theme builder** lets players change any role colour and see it live. They can save the result under a name, copy it as text, and import text someone else copied.

From your own code you can call:

- `Window:SetPersonal(key, value)`, with key `Font`, `TextSize`, `Radius`, `Density`, `Transparency`, `NoticePosition`, `AccentGradient` or `SafeStatus`;
- `Window:PersonaliseSection(tab)` and `Window:ThemeBuilder(tab)`, to place the sections on any tab.

Built-in themes: Midnight, Onyx, Rose, Aqua, Ember, Forest, Amethyst, Crimson, Glacier, Daylight, OLED, Contrast, Sunset, Ocean, Aurora and Latte. Every text colour has a contrast of 4.5 or more against each surface it's drawn on.
