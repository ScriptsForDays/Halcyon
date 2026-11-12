# API reference

Everything below is called with a table of options. An option marked *(default …)* can be left out.

- [Library](#library)
- [Window](#window)
- [Tabs and sections](#tabs-and-sections)
- [Elements](#elements)
- [Notifications and dialogs](#notifications-and-dialogs)
- [Configs](#configs)
- [Settings tab and overlays](#settings-tab-and-overlays)

## Library

```lua
local Halcyon = loadstring(game:HttpGet("https://raw.githubusercontent.com/ScriptsForDays/Halcyon/main/dist/Halcyon.luau"))()
```

| Call | Does |
|---|---|
| `Halcyon:CreateWindow(options)` | Creates a window. With a `KeySystem` it yields until a key is accepted and returns `nil` if the player closes the prompt |
| `Halcyon:Authenticate(keyOptions)` | Runs the key prompt alone. Yields; returns the access table or `nil` |
| `Halcyon:Notify(options)` | Shows a notification; returns `{ Dismiss }` |
| `Halcyon:SetNotificationDefaults(settings)` | Sets `Duration`, `Position`, `Progress`, `MaxVisible` for later notices |
| `Halcyon:Dialog(options)` | Shows a modal dialog |
| `Halcyon:SetTheme(name)` / `:GetTheme()` / `:GetThemes()` | Theme by name |
| `Halcyon:AddTheme(palette)` | Registers a theme; returns `ok, message` |
| `Halcyon:SetAccent(color)` | Recolours the accent of any theme; `nil` restores it |
| `Halcyon:AddIconPack(name, icons)` / `:SetIconPack(name)` | Custom icon packs; the default pack |
| `Halcyon:SetFont(font)` | A font family string, `Font` or `Enum.Font`, for everything created afterwards |
| `Halcyon:GetExecutor()` | The executor's name and version |
| `Halcyon:Unload()` | Unloads every window |
| `Halcyon.Version`, `Halcyon.ThemeChanged` | The version string; a signal fired with the new theme's name |

## Window

### Options for `CreateWindow`

| Option | Meaning |
|---|---|
| `Title`, `Subtitle`, `Icon` | Shown in the top bar |
| `Version` | Text for the version tag beside the title, such as `"v1.2.0"`. `ShowVersion = false` hides the tag |
| `Folder` | Where configs and settings save: `Halcyon/<Folder>/`. *(default: the Title)* Also identifies the hub, so running it twice replaces the first window |
| `Theme` | A theme name, or a palette table to register and use |
| `TabStyle` | `"Sidebar"` *(default)*, `"Rail"`, `"Top"` or `"Dock"` |
| `SectionStyle` | `"Card"` *(default)*, `"Outlined"` or `"Flat"` |
| `Size` | A `Vector2` or offset `UDim2`. *(default 740 x 500)* Always fitted to the screen |
| `Scale` | 0.75 to 1.25 *(default 1)* |
| `ToggleKey` | The menu key *(default `Enum.KeyCode.RightShift`)* |
| `ButtonEffect` | The finish on filled, outline and danger buttons: `"Sweep"` *(default)*, `"Ripple"`, `"Lift"`, `"Glow"` or `"None"` |
| `ShadowTransparency`, `ShadowImage` | The window shadow's strength *(default 0.5)* and a replacement nine-slice image |
| `LockHint`, `PaidLockHint` | The second line on a locked section's overlay *(default for paid locks: `"Unlock with a paid key"`)* |
| `Font`, `IconPack`, `DisplayOrder` | Font family, default icon pack, ScreenGui order *(default 100)* |
| `Profile` | `false` for no profile card, or a table: see below |
| `KeySystem` | See [key-system.md](key-system.md) |
| `Tiers`, `Tier`, `PaidTier` | Tiers without the prompt, for hubs with their own login: a list of names, the player's tier, and which one is paid *(default `"Paid"`)* |
| `LockText`, `PaidLockText` | Wording on locked rows *(defaults `"Requires {tier}"` and `"Paid only"`)* |
| `Notifications` | Defaults for notices: `{ Duration, Position, Progress, MaxVisible }` |
| `MinimizeStyle` | `"Topbar"` *(default)*, `"Pill"` or `"Chip"` |
| `SliderTooltipStyle` | `"Rounded"` *(default)*, `"Sharp"`, `"Pill"` or `"Plain"` |
| `ToggleOutlineColor` | A `Color3` for the toggle hover outline *(default: the accent)* |
| `ToggleThumb` | The shape of every switch's thumb: `"Circle"` *(default)*, `"Oval"` or `"Square"` |
| `CollapsedGroups` | Sidebar groups that start folded, by name |

Switches, all on unless set to `false`: `ShowVersion`, `Shadow`, `Search`, `Resizable`, `Minimizable`, `CollapsibleGroups`, `SliderTooltips`, `ToggleOutline`, `SavePreferences`. `OpenButton = true` shows the round open button on desktop too when the window is hidden.

### Profile

```lua
Profile = {
	Avatar = "Headshot", -- or "Viewport" (a 3D view of the character) or "None"
	Anonymous = false, -- hide the name and avatar
	ShowUsername = true,
	ShowTier = true, -- the key tier, or "Keyless"
	ShowExecutor = true,
	ShowClock = true,
	ShowDate = false,
	ClockFormat = "%H:%M", -- os.date patterns
	DateFormat = "%d %b %Y",
	Name = nil, -- text in place of the display name
	Subtitle = nil, -- text in place of @username
}
```

### Methods

| Call | Does |
|---|---|
| `Window:Tab(options)` | Adds a tab |
| `Window:SelectTab(tab)` | Opens a tab |
| `Window:SettingsTab(options)` | Adds the ready-made Settings tab |
| `Window:Show()`, `:Hide()`, `:Toggle()` | Visibility |
| `Window:Minimize(bool)`, `:SetMinimizeStyle(name)` | Minimising |
| `Window:Search(text)` | Fills the search box |
| `Window:SetTabStyle(name)`, `:SetScale(number)`, `:SetToggleKey(keyCode)` | Layout and menu key |
| `Window:SetTitle(text)`, `:SetSubtitle(text)` | Top bar text |
| `Window:SetVersion(text)`, `:SetVersionVisible(bool)` | The version tag |
| `Window:SetAnonymous(bool)`, `:SetProfile(settings)` | Profile card |
| `Window:SetAccent(color)`, `:SetReducedMotion(bool)` | Appearance |
| `Window:SetGroupCollapsed(name, bool)` | Folds a sidebar group |
| `Window:SetSliderTooltips(enabled, style)` | Slider tooltips for the whole window |
| `Window:SetToggleOutline(enabled, color)` | Toggle hover outline; `color` is a `Color3`, or `false` for the accent |
| `Window:SetLockText(text, paidText)` | Wording on locked rows and sections |
| `Window:SetLockHint(hint, paidHint)` | The second line on locked sections |
| `Window:GetKeyExpiry()` | Seconds until the key expires, or `nil` |
| `Window:GetTier()`, `:HasTier(name)`, `:IsPaid()`, `:SetTier(name)` | Tiers |
| `Window:Notify(options)`, `:Dialog(options)` | Feedback |
| `Window:Watermark(options)`, `:KeybindList(options)` | Overlays |
| `Window:SaveConfig(name)` and the other config calls | See [Configs](#configs) |
| `Window:Unload()` | Removes the window and everything it made |

Fields: `Window.Flags` (handles by flag), `Window.OnUnload`, `Window.TabChanged`, `Window.KeybindsChanged` (signals with `:Connect`), `Window.Visible`.

## Tabs and sections

```lua
local Tab = Window:Tab({ Title = "Combat", Icon = "sword", Group = "Game" })
local Section = Tab:Section({ Title = "Aim", Icon = "target", Side = "Right" })
```

| Tab option | Meaning |
|---|---|
| `Title`, `Icon` | Shown on the tab button |
| `Group` | A heading above this tab in the sidebar; tabs that share it sit together and fold together |
| `SectionStyle` | The default style for this tab's sections |
| `Tier`, `PaidOnly`, `LockText` | Lock every row in the tab |

| Section option | Meaning |
|---|---|
| `Title`, `Icon` | The header. Without a Title there is no header |
| `Style` | `"Card"`, `"Outlined"` or `"Flat"` |
| `Side` | `"Left"` *(default)* or `"Right"`. Two columns show when the page is wide enough |
| `Collapsible` *(default true)*, `Collapsed` | Folding by pressing the header |
| `Tier`, `PaidOnly`, `LockText`, `LockHint` | Lock the section: one overlay with an icon, the wording and a hint covers its rows |

`Tab:Select()`, `Tab:SetTitle(text)`. `Section:SetTitle(text)`, `:SetCollapsed(bool)`, `:SetVisible(bool)`, `:Destroy()`.

Elements can be added to a tab directly; they go into an untitled flat section.

## Elements

Every element is created on a tab or section and returns a handle.

**Options every element takes:** `Title` (required, except Divider, Code and Image), `Description`, `Icon` (a leading icon), `Flag` (saves the value in configs), `Callback`, `Tier` (a tier name), `PaidOnly`, `LockText`.

**Every handle has:** `Get()`, `Set(value)`, `Changed` (a signal), `SetTitle(text)`, `SetDescription(text)`, `SetDisabled(bool)`, `SetVisible(bool)`, `Lock(text, icon)`, `Unlock()`, `IsLocked()`, `Destroy()`, `Frame`, `Kind`, `Flag`.

**When a Callback runs:** on every `Set`, even to the same value, which is what makes loading a config start what it restores. Not on creation, with one exception: a Toggle with `Default = true` runs its Callback once, deferred, because a switch drawn on must mean the feature is on. A Slider's `Default` is only shown.

| Element | Options | Value |
|---|---|---|
| `Button` | `Variant` (`"Filled"`, `"Outline"`, `"Danger"`; without it the whole row is the button), `Effect`, `TrailingIcon` | none; `Press()` runs it |
| `Toggle` | `Default`, `Style` (`"Switch"` or `"Checkbox"`), `Thumb` (`"Circle"`, `"Oval"`, `"Square"`), `Keybind`, `Color`, `Outline`, `OutlineColor` | boolean |
| `Slider` | `Min`, `Max`, `Step`, `Default`, `Suffix`, `Stacked`, `Range`, `Width`, `Tooltip`, `TooltipStyle` | number; `{ low, high }` with `Range` |
| `Dropdown` | `Values`, `Default`, `Multi`, `AllowNone`, `Searchable`, `Placeholder`, `Width`; `Refresh(values)` | one value or `nil`; a list with `Multi` |
| `Input` | `Default`, `Placeholder`, `Numeric`, `Min`, `Max`, `Live`, `MaxLength`, `Width` | string; number with `Numeric` |
| `Keybind` | `Default`, `Mode` (`"Press"`, `"Toggle"`, `"Hold"`), `ChangedCallback` | `Enum.KeyCode` or `nil` |
| `ColorPicker` | `Default`, `Alpha`, `Transparency` | `Color3`, transparency |
| `Segmented` | `Values`, `Default`, `Stacked` | one of `Values` |
| `Stepper` | `Min`, `Max`, `Step`, `Default`, `Suffix` | number |
| `Progress` | `Value`, `Max` *(default 100)*, `Suffix` | number |
| `Paragraph` | `Content`; `Set(text)` or `Set({ Title, Content })` | none |
| `Label` | a string, or `{ Title }` | none |
| `Divider` | `Title` | none |
| `Code` | `Title`, `Code`; has a copy button | string |
| `Image` | `Image`, `Height`, `Crop` | none |

### Notes

- **Toggle add-ons.** `Keybind = { Default = Enum.KeyCode.F, Mode = "Toggle" or "Hold", Flag = "FlyKey" }` puts a key chip beside the switch; `Color = { Default = Color3, Alpha = true, Flag = "FlyColor", Callback = fn }` puts a colour swatch there. They are reachable as `handle.Keybind` and `handle.Color`.
- **Toggle motion.** A switch's thumb stretches toward its new side and settles with a small overshoot; a checkbox's tick pops in. With reduced motion on, both change at once.
- **Toggle outline.** `Outline = false` turns the hover outline off for one toggle; `OutlineColor = Color3` gives it its own colour.
- **Slider tooltip.** `Tooltip = false` hides the value bubble for one slider; `TooltipStyle` picks its shape. The bubble never covers the slider's value box.
- **Keybind.** Press the chip, then a key. Escape cancels, Backspace clears. A key typed into a text box is ignored.
- **ColorPicker.** `Set` takes a `Color3` or a hex string. The Callback runs when a drag ends, not on every move.
- **Narrow rows.** In a two-column page or on a phone, a slider's track, a dropdown, an input and a segmented control move under their title at full width, so a title is never squeezed.

## Notifications and dialogs

```lua
Window:Notify({
	Title = "Config saved",
	Content = "Your settings were written to disk.",
	Kind = "success", -- "info", "success", "warning" or "danger"
	Duration = 8, -- seconds; 0 stays until tapped
	Progress = true, -- the countdown bar
	Actions = { { Title = "Undo", Callback = function() end }, { Title = "Dismiss" } },
})

Halcyon:SetNotificationDefaults({ Duration = 6, Position = "TopRight", MaxVisible = 3, Progress = true })
```

`Position` is one of `TopLeft`, `TopCenter`, `TopRight`, `BottomLeft`, `BottomCenter`, `BottomRight`. On a narrow screen notices always sit across the top. Notify on results the player cannot see (saved, failed, loaded), not on every toggle.

```lua
Window:Dialog({
	Title = "Delete this config?",
	Content = "The file is removed from this device.",
	Buttons = {
		{ Title = "Keep" },
		{ Title = "Delete", Variant = "Danger", Callback = function() end },
	},
})
```

Button `Variant` is `"Primary"`, `"Danger"` or left out. `Dismissible = true` lets a press outside close it.

## Configs

A config holds the value of every element that has a `Flag`.

| Call | Does |
|---|---|
| `Window:SaveConfig(name)` | Writes `Halcyon/<Folder>/configs/<name>.json` |
| `Window:LoadConfig(name)` | Sets every saved flag the hub still has |
| `Window:DeleteConfig(name)`, `:ListConfigs()` | Manage files |
| `Window:SetAutoload(name)`, `:GetAutoload()`, `:LoadAutoload()` | Mark a config to load on start; call `LoadAutoload()` after every element exists |

Each returns `ok, message`; the message is written for the player. Without file functions they return `false` and say so. Names are limited to letters, numbers, spaces, `-` and `_`.

Loading a config calls `Set` on each flag, which runs its Callback. Give a `Flag` only to settings you want restored; leave it off a toggle that should never start by itself.

The player's interface choices (theme, navigation, scale, menu key, minimise style, folded groups, anonymous mode, reduced motion) save on their own to `Halcyon/<Folder>/settings.json`, unless `SavePreferences = false`.

## Settings tab and overlays

```lua
Window:SettingsTab({ Title = "Settings", Icon = "settings", Group = "Library" })
```

Each row is on unless its switch is `false`: `Theme`, `Accent`, `Navigation`, `Scale`, `ReduceMotion`, `MenuKey`, `Minimize`, `Anonymous`, `Configs`, `Unload`.

```lua
local mark = Window:Watermark({ Fields = { "Title", "User", "Executor", "FPS", "Ping", "Time", "Date" } })
local binds = Window:KeybindList({ Title = "Keybinds" })
mark:SetVisible(false)
binds:Destroy()
```

A watermark field may also be any text or a function returning text. Both overlays can be dragged.
