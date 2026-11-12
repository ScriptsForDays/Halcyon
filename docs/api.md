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
| `SectionStyle` | `"Card"` *(default)*, `"Outlined"`, `"Flat"`, `"Glass"`, `"Accent"`, `"Inset"` or `"Header"` |
| `Size` | A `Vector2` or offset `UDim2`. *(default 740 x 500)* Always fitted to the screen |
| `Scale` | 0.75 to 1.25 *(default 1)* |
| `ToggleKey` | The menu key *(default `Enum.KeyCode.RightShift`)* |
| `ButtonEffect` | The finish on filled, outline and danger buttons: `"Sweep"` *(default)*, `"Ripple"`, `"Lift"`, `"Glow"` or `"None"` |
| `ShadowTransparency`, `ShadowImage` | The window shadow's strength *(default 0.5)* and a replacement nine-slice image |
| `LockHint`, `PaidLockHint` | The second line on a locked section's overlay *(default for paid locks: `"Unlock with a paid key"`)* |
| `Font`, `IconPack`, `DisplayOrder` | Font family, default icon pack, ScreenGui order *(default 2147483000, above the game's own screens)* |
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
| `TopbarImage`, `TopbarImageStyle` | A picture before the title (any image source, or `true` for the window `Icon`) in a `"Circle"`, `"Rounded"`, `"Square"`, `"Squircle"`, `"Ring"` or `"Badge"` shape. `false` keeps the plain icon |
| `UpdateLog` | `true`, or `{ Title, Icon, Group, Style = "Timeline" \| "Cards" \| "Compact", Popup, Search, Filters, ExpandAll, Updates = { ... } }`: a tab of releases. See [Update log](#update-log) |
| `Preset` | A coordinated set of looks: `"Classic"`, `"Minimal"`, `"Glass"`, `"Neon"`, `"Compact"`. What you set yourself wins |
| `Styles` | A default look per kind, such as `{ Toggle = "Slim", Slider = "Thick" }`; see [styles.md](styles.md) |
| `WindowStyle`, `Transparency`, `BackgroundImage` | `"Solid"`, `"Glass"`, `"Gradient"` or `"Image"`; how see-through (0 to 0.6); a picture behind the contents |
| `OpenAnimation`, `PageTransition`, `TabIndicator`, `TopbarControls` | How the window appears, how a page arrives, how the open tab is marked, and `"Mac"` dot buttons |
| `Radius`, `Density`, `TextSize` | Corner, spacing and text-size settings |
| `AccentGradient`, `SafeStatusColors` | A second accent colour for fills; colour-blind-friendly status colours |
| `SidebarWidth`, `SidebarToggle`, `Snap` | Sidebar width, a button that folds it, snapping to screen edges |
| `CommandPalette`, `PaletteKey` | Ctrl+K search over every tab and setting, and its key |

Switches, all on unless set to `false`: `ConfirmUnload` (the Unload button asks first), `LockShimmer` (the light across locked rows), `ShowVersion`, `Shadow`, `Search`, `Resizable`, `Minimizable`, `CollapsibleGroups`, `SliderTooltips`, `ToggleOutline`, `SavePreferences`, `FocusRing`. `OpenButton = true` shows the round open button on desktop too when the window is hidden.

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
| `Window:RequestUnload()` | What the Unload button does: asks first unless `ConfirmUnload = false` |
| `Window:Unload()` | Removes the window and everything it made, without asking |
| `Window:ConfigSection(tabOrSection, options)` | The config block (name, save with overwrite check, load, delete, load on start) anywhere you like |
| `Window:ConfigExists(name)` | Whether a config with that name is saved |
| `Window:Require(names)` | The executor functions in the list this executor lacks |
| `Window:SetTransparency(n)` | How much of the game shows through, 0 to 0.6 |
| `Window:SetEnabled(bool)` | Greys every control at once; rows the hub disabled stay disabled |
| `Window:AddTopbarButton({ Icon, Callback })` | A button in the top bar; returns `{ Destroy }` |
| `Window:SetPersonal(key, value)` | A player look setting, applied live and saved; see [styles.md](styles.md) |
| `Window:PersonaliseSection(tab)`, `:ThemeBuilder(tab)` | The personalise rows and the theme builder on any tab |
| `Window:OpenPalette()` | The search over every tab and row (Ctrl+K with `CommandPalette = true`) |
| `Window:Loading(options)` | A loading screen that moves only as you report progress: `SetProgress(fraction, text)`, `Done()` |
| `Window:Changelog({ Version, Entries, Force })` | A "What's new" card, shown once per version |
| `Window:About(tab, options)` | Credits and links the player can copy (`Description`, `Credits`, `Discord`, `Links`) |
| `Window:AddUpdate(release)` | Adds a release to the update log |
| `Window:Lock(options)`, `:Unlock()` | Covers the window with a message (`Title`, `Text`, `Icon`, `Button`) |

Fields: `Window.Flags` (handles by flag), `Window.ConfigChanged` (fires `action, name` after a save, load, delete or autoload), `Window.OnUnload`, `Window.TabChanged`, `Window.KeybindsChanged` (signals with `:Connect`), `Window.Visible`.

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
| `Description` | A heading with this line at the top of the page |
| `Tier`, `PaidOnly`, `LockText` | Lock every row in the tab |

| Section option | Meaning |
|---|---|
| `Title`, `Icon` | The header. Without a Title there is no header |
| `Style` | `"Card"`, `"Outlined"`, `"Flat"`, `"Glass"`, `"Accent"`, `"Inset"` or `"Header"` |
| `Description`, `Badge`, `IconColor` | A line under the title, a count or word beside it, the icon's colour (a role name or `Color3`) |
| `Tabs` | Names of tabs inside the box: `box:Tab("Visuals"):Toggle({...})`; elements added to the section go to the first |
| `Switch` | `{ Default, Flag, Callback }`: a switch in the header that greys the rows while off |
| `MaxHeight` | The rows scroll past this height |
| `Side` | `"Left"` *(default)* or `"Right"`. Two columns show when the page is wide enough |
| `Collapsible` *(default true)*, `Collapsed` | Folding by pressing the header |
| `Tier`, `PaidOnly`, `LockText`, `LockHint` | Lock the section: one overlay with an icon, the wording and a hint covers its rows |

`Tab:Select()`, `Tab:SetTitle(text)`, `Tab:SetBadge(value)` (a number, a short word, `true` for a dot, `nil` to clear), `Tab:Notice({ Title, Content, Kind, Dismissible })` (a callout at the top of the page), `Tab:EmptyState({ Icon, Title, Text, Kind = "error", Button })`, `Tab:About(options)`. `Section:SetTitle(text)`, `:SetBadge(value)`, `:SetCollapsed(bool)`, `:SetVisible(bool)`, `:SelectTab(name)`, `:ShowWhen(source, value)`, `:Destroy()`.

Elements can be added to a tab directly; they go into an untitled flat section.

## Elements

Every element is created on a tab or section and returns a handle.

**Options every element takes:** `Title` (required, except Divider, Code and Image), `Description`, `Icon` (a leading icon), `Flag` (saves the value in configs), `Callback`, `Tier` (a tier name), `PaidOnly`, `LockText`, `Badge` (`"New"`, `"Beta"`, `"Risky"`, `"Paid"`, any text, or `{ Text, Color }`), `Info` (a longer explanation behind an info icon), `Requires` (executor functions the row needs; without them it is locked with their names), `Style` (a look; see [styles.md](styles.md)), `Tooltip` (hover text, or `{ Title, Text, Key, Style }`), `Spotlight` (`{ Title, Text, Id }`: a one-time pointer at a new feature).

**Every handle has:** `Get()`, `Set(value)`, `Changed` (a signal), `SetTitle(text)`, `SetDescription(text)`, `SetDisabled(bool)`, `SetVisible(bool)`, `Lock(text, icon)`, `Unlock()`, `IsLocked()`, `ShowWhen(source, value)` (visible only while another element, or its Flag, has that value; `value` may be a function), `Spotlight(options)`, `Destroy()`, `Frame`, `Kind`, `Flag`.

**When a Callback runs:** on every `Set`, even to the same value, which is what makes loading a config start what it restores. Not on creation, with one exception: a Toggle with `Default = true` runs its Callback once, deferred, because a switch drawn on must mean the feature is on. A Slider's `Default` is only shown.

| Element | Options | Value |
|---|---|---|
| `Button` | `Variant` (a Button look; without it the whole row is the button), `Icon`, `Effect`, `TrailingIcon`, `Hold` (seconds to hold), `Confirm` (true or the wording of a confirming second press), `ShowDone` (a tick or cross after the Callback); `SetLoading(bool, text)`, `IsLoading()` | none; `Press()` runs it |
| `Buttons` | `Buttons = { { Title, Icon, Variant, Callback } }`, optional `Title`: several buttons sharing one row | none |
| `Toggle` | `Default`, `Style` (a Toggle look), `Thumb` (`"Circle"`, `"Oval"`, `"Square"`), `Keybind`, `Color`, `Outline`, `OutlineColor` | boolean |
| `Slider` | `Min`, `Max`, `Step`, `Default`, `Suffix`, `Prefix`, `Percent`, `Format` (value to text), `Display` (`"Box"`, `"Text"`, `"Fraction"`, `"None"`), `DefaultMarker`, `Stacked`, `Range`, `Width`, `Tooltip`, `TooltipStyle`, `Live` | number; `{ low, high }` with `Range` |
| `Dropdown` | `Values` (plain values or `{ Text, Value, Icon, Image, Description, Disabled }`, `{ Heading = "..." }`), `Default`, `Multi`, `AllowNone`, `Searchable`, `Placeholder`, `Width`, `Players` (with `ExcludeSelf`); `Refresh(values)` | one value or `nil`; a list with `Multi` |
| `Radio` | `Values`, `Default`, `Inline`, `AllowNone` | one value |
| `Checklist` | `Values`, `Default`, `Inline`, `SelectAll` | a list |
| `Chips` | `Values`, `Default`, `Multi` | one value, or a list with `Multi` |
| `Tiles` | `Items` (`{ Title, Icon, Image, Description, Value }`), `Columns`, `Multi`, `Default`, `Height` | one value, or a list with `Multi` |
| `Input` | `Default`, `Placeholder`, `Numeric`, `Min`, `Max`, `Live`, `MaxLength`, `Width`, `LeadingIcon`, `Clearable`, `Counter`, `Password`, `MultiLine` (with `Lines`) | string; number with `Numeric` |
| `Keybind` | `Default`, `Mode` (`"Press"`, `"Toggle"`, `"Hold"`), `ModePicker` (right-click or long press to change mode), `ChangedCallback`, `ModeChangedCallback`; `GetMode()`, `SetMode(name)` | `Enum.KeyCode` or `nil` |
| `ColorPicker` | `Default`, `Alpha`, `Transparency`, `Palette` (`true` or a list of `Color3`), `Recent` | `Color3`, transparency |
| `DatePicker` | `Default` (`{ Year, Month, Day, Hour, Minute }`), `Time`, `WeekStart`; `GetTimestamp()` | that table |
| `Segmented` | `Values`, `Default`, `Stacked` | one of `Values` |
| `Stepper` | `Min`, `Max`, `Step`, `Default`, `Suffix`, `Drag` (drag the number sideways; on by default) | number |
| `Rating` | `Max` *(default 5)*, `Default`, `Icon`, `AllowNone` | number |
| `Progress` | `Value`, `Max` *(default 100)*, `Suffix` | number |
| `Status` | `Status` (the words), `Kind`, `Pulse`; `SetStatus(text, kind)` | the words |
| `Countdown` | `Seconds` or `Ends` (an `os.time()`), `Done`, `Format`, `Callback` (at zero) | seconds left |
| `Table` | `Columns` (`"Name"` or `{ Title, Width, Align }`), `Rows`, `Sortable`, `MaxHeight`, `Striped`, `EmptyText`; `SetRows`, `AddRow`, `Clear` | the rows |
| `Accordion` | `Content`, `Open`; `SetOpen(bool)` | open or not |
| `Paragraph` | `Content` (rich text), `Image`, `ImageSize`, `Buttons`; `Set(text)` or `Set({ Title, Content })` | none |
| `Label` | a string, or `{ Title, Style }`; `Style` `"Info"`, `"Success"`, `"Warning"`, `"Danger"` or `"Note"` makes a callout; `SetKind(name)` | none |
| `Space` | `Height` | none |
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
	Style = "Default", -- or "Timer", "Compact", "Banner", "Progress", "Accent", "Glass", "Achievement", "Snackbar", "Island"
	Sound = false, -- true for a short chime, or a sound id
	Actions = { { Title = "Undo", Callback = function() end }, { Title = "Dismiss" } },
})

Halcyon:SetNotificationDefaults({ Duration = 6, Position = "TopRight", MaxVisible = 3, Progress = true, Style = "Default" })

-- Work that takes a while: the notice stays until Done.
local job = Window:Notify({ Title = "Downloading", Content = "0 of 10", Style = "Progress" })
job.SetProgress(0.5) -- 0 to 1
job.SetContent("5 of 10")
job.Done("Downloaded") -- fills the bar, turns green, leaves after a moment
```

| Style | Looks like |
|---|---|
| `Default` | A card with a countdown bar along the bottom |
| `Timer` | The seconds left, counting down in the corner |
| `Compact` | One line in a pill: icon and title |
| `Banner` | A coloured strip across the top |
| `Progress` | A bar the hub fills; stays until `Done` |
| `Accent` | A card with a coloured edge and the icon on a tinted disc |
| `Glass` | A see-through card |
| `Achievement` | A large icon disc, for a reward or milestone |
| `Snackbar` | A dark one-line bar; its first action shows as a word, such as Undo |
| `Island` | A pill at the top centre, apart from the stack |

Every notice returns a handle with `Dismiss`, `SetTitle`, `SetContent`, `SetProgress` and `Done`.

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

Button `Variant` is `"Primary"`, `"Danger"`, `"Ghost"` or left out; `Delay = 3` holds a button back for three seconds with a countdown on it. `Dismissible = true` lets a press outside, or Escape, close it.

## Images

Anywhere Halcyon takes an image or icon (window and tab icons, `TopbarImage`, the Image element, Paragraph and dropdown pictures, tiles, `BackgroundImage`, notice and key prompt icons) it accepts:

- an icon name (`"sword"`, `"solar:home"`);
- an asset id (`1234`, `"rbxassetid://1234"`, `"rbxthumb://..."`);
- an `http(s)` URL;
- a file in the executor's workspace (`"myhub/logo.png"`).

URLs are downloaded once to `Halcyon/assets/` and shown through `getcustomasset`. Files are passed to `getcustomasset` directly and must stay inside the workspace. Images over 5 MB are refused. Without `getcustomasset` (Roblox Studio, some executors) an image icon shows instead.

`Halcyon:Image(source, callback)` resolves one for your own use: it returns the id when it is ready, otherwise calls `callback(id, problem)`.

## Discord buttons

`KeySystem = { Discord = "https://discord.gg/yourcode" }` puts a round invite button under the key prompt. `Profile = { Discord = "https://discord.gg/yourcode" }` puts one on the profile card. Each is separate and off unless given; `false` leaves it out. Pressing it copies the invite and tells the player. Pass `{ Link, Icon, Label }` instead of a string to change the mark or the prompt's label.

## Update log

```lua
local Window = Halcyon:CreateWindow({
	Title = "My Hub",
	UpdateLog = {
		Popup = true, -- show the newest release once as a What's new card
		Updates = {
			{ Version = "1.2.0", Date = "12 Nov 2026", Title = "Auto farm", Summary = "Optional line under the title", Entries = {
				{ Kind = "New", Text = "Auto farm for the mines" },
				{ Kind = "Fixed", Text = "Teleports no longer fail after respawn" },
			} },
		},
	},
})
Window:AddUpdate({ Version = "1.2.1", Entries = { { Kind = "Fixed", Text = "Crash on join" } } })
```

Releases are ordered by version number (1.10 comes after 1.9), newest first; `Pinned = true` keeps one on top. Entry kinds are New, Improved, Fixed, Removed and Security; a plain string is New. The newest release is open, older ones are folded, and the tab carries a badge until the player opens it. Players can search and filter by kind. Looks: Timeline (default), Cards, Compact. `UpdateLog = false` builds nothing.

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

Each row is on unless its switch is `false`: `Theme`, `Accent`, `Navigation`, `Scale`, `ReduceMotion`, `MenuKey`, `Minimize`, `Anonymous`, `Configs`, `Unload`. `ScaleControl = "Slider"` shows the interface scale as a slider instead of a stepper. `Personalise = true` and `ThemeBuilder = true` add the player's look settings and the theme builder.

```lua
local mark = Window:Watermark({ Fields = { "Title", "User", "Executor", "FPS", "Ping", "Time", "Date" } })
local binds = Window:KeybindList({ Title = "Keybinds" })
mark:SetVisible(false)
binds:Destroy()
```

A watermark field may also be any text or a function returning text. Both overlays can be dragged. `Style` picks a look: Card, Pill, Accent or Minimal for the watermark; Card, Glass or Minimal for the keybind list.
