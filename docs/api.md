# API reference

Everything below is called with a table of options. An option marked *(default …)* can be left out.

- [Library](#library)
- [Window](#window)
- [Switches](#switches)
- [Header styles](#header-styles)
- [Tabs and sections](#tabs-and-sections)
- [Elements](#elements)
- [Sheets and the quick bar](#sheets-and-the-quick-bar)
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
| `Halcyon:GetStyles(kind)`, `:GetPresets()`, `:GetSwitches()` | The names of a kind's looks, of the presets, and of every window switch |
| `Halcyon:Unload()` | Unloads every window |
| `Halcyon.Version`, `Halcyon.ThemeChanged` | The version string; a signal fired with the new theme's name |

## Window

### Options for `CreateWindow`

| Option | Meaning |
|---|---|
| `Title`, `Subtitle`, `Icon` | Shown in the top bar. `Icon = false` shows no icon |
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
| `HeaderStyle`, `Logo` | Where the title and logo go, and the logo itself. See [Header styles](#header-styles) |

The parts that turn on and off are listed under [Switches](#switches).

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
| `Window:Set(name, value)`, `:Get(name)` | Turns a switch on or off while the hub runs, and reads it. See [Switches](#switches) |
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
| `Window:Sheet(options)`, `:QuickBar(options)` | A side panel and a floating bar. See [Sheets and the quick bar](#sheets-and-the-quick-bar) |

Fields: `Window.Flags` (handles by flag), `Window.ConfigChanged` (fires `action, name` after a save, load, delete or autoload), `Window.OnUnload`, `Window.TabChanged`, `Window.KeybindsChanged` (signals with `:Connect`), `Window.Visible`.

## Switches

Each built-in part is one option on `CreateWindow`. Leave it out for the default, set it to `false` to leave the part out, or `true` to add it; the ones marked *table* also take their settings in place of `true`. `Window:Set(name, value)` changes a switch while the hub runs, `Window:Get(name)` reads it, and `Halcyon:GetSwitches()` lists every name they take.

| Switch | Default | What it controls |
|---|---|---|
| `Search` | on | The search box |
| `Profile` | on | The profile card; *table* (see [Profile](#profile)) |
| `ShowVersion` | on | The version tag beside the title |
| `Minimize` | on | The minimise button. The old name `Minimizable` still works |
| `Close` | on | The close button |
| `Resize` | on | The resize grip. The old name `Resizable` still works |
| `Drag` | on | Dragging the window by its top bar, or by the logo in the `Sidebar` header |
| `Shadow` | on | The soft shadow under the window |
| `Tooltips` | on | Hover tips on rows |
| `Animations` | on | Motion. Off is the same as `SetReducedMotion(true)` |
| `Blur` | off | A blur over the game while the window is open; a number sets its size *(default 12)* |
| `CommandPalette` | off | Ctrl+K search over every tab and setting |
| `NotificationCenter` | off | A bell in the top bar. Its badge counts notices since the player last looked; pressing it lists them with a Clear all button |
| `Watermark` | off | The watermark; *table* (see [Settings tab and overlays](#settings-tab-and-overlays)) |
| `KeybindList` | off | The keybind list; *table* |
| `SettingsTab` | off | The ready-made settings tab; *table* of the same options as `Window:SettingsTab` |
| `Snap` | off | Snapping the window to screen edges |
| `OpenButton` | off | The round open button on desktop while the window is hidden. Touch screens always show it |

Read once, when the window is made: `Icon`, `TopbarImage` and `Logo` (`false` leaves the picture out), `CollapsibleGroups`, `SliderTooltips`, `ToggleOutline`, `ConfirmUnload` (the Unload button asks first), `LockShimmer` (the light across locked rows), `FocusRing` and `SavePreferences`. All of these are on unless set to `false`.

Tabs, sections and elements take their own switches when they are made:

| Option | Does |
|---|---|
| `Visible = false` | Makes it hidden; `SetVisible(true)` shows it later |
| `Disabled = true` | Greys it and ignores input; `SetEnabled(true)` or `SetDisabled(false)` turns it back on |
| `ShowWhen = "Flag"` or `{ "Flag", value }` | Shown only while that flag holds `value` *(default `true`)*. `value` may be a function of the flag's value |
| `EnableWhen = "Flag"` or `{ "Flag", value }` | The same, but greyed instead of hidden |

The flag may belong to an element made later in the script. The same calls work afterwards as methods: `handle:ShowWhen(source, value)` and `handle:EnableWhen(source, value)`, where `source` is a handle or a flag name.

## Header styles

| `HeaderStyle` | Layout |
|---|---|
| `"Bar"` *(default)* | The top bar: icon or picture, title, subtitle and version tag |
| `"Tall"` | A taller top bar with a larger picture beside the title and subtitle |
| `"Wordmark"` | A wide logo image in place of the title words |
| `"Sidebar"` | A big logo at the top of the sidebar, search under it, and no top bar. Minimise and close sit small in the page's top-right corner, and minimising folds to a pill |

`Logo` takes any image source (asset id, URL, workspace file or icon name), or a table `{ Image, Text, Icon, Height, Width }`. With no image it draws `Text` (or the window's `Title`) as a large wordmark beside the `Icon`, so it works in Studio and without `getcustomasset`. `Logo = false` draws no logo. When the window is too narrow for a sidebar, or the tab style is a rail or a strip, the `Sidebar` style puts the logo back in a top bar.

## Tabs and sections

```lua
local Tab = Window:Tab({ Title = "Combat", Icon = "sword", Group = "Game" })
local Section = Tab:Section({ Title = "Aim", Icon = "target", Side = "Right" })
```

| Tab option | Meaning |
|---|---|
| `Title`, `Icon` | Shown on the tab button |
| `Visible`, `ShowWhen` | Hide the tab, or show it only while a flag holds a value. See [Switches](#switches) |
| `Group` | A heading above this tab in the sidebar; tabs that share it sit together and fold together |
| `SectionStyle` | The default style for this tab's sections |
| `Description` | A heading with this line at the top of the page |
| `Tier`, `PaidOnly`, `LockText` | Lock every row in the tab |

| Section option | Meaning |
|---|---|
| `Title`, `Icon` | The header. Without a Title there is no header |
| `Style` | `"Card"`, `"Outlined"`, `"Flat"`, `"Glass"`, `"Accent"`, `"Inset"`, `"Header"` or `"Panel"` (each row on its own inset card) |
| `Visible`, `Disabled`, `ShowWhen`, `EnableWhen` | See [Switches](#switches) |
| `Description`, `Badge`, `IconColor` | A line under the title, a count or word beside it, the icon's colour (a role name or `Color3`) |
| `Tabs` | Names of tabs inside the box: `box:Tab("Visuals"):Toggle({...})`; elements added to the section go to the first |
| `Switch` | `{ Default, Flag, Callback }`: a switch in the header that greys the rows while off |
| `MaxHeight` | The rows scroll past this height |
| `Side` | `"Left"` *(default)* or `"Right"`. Two columns show when the page is wide enough |
| `Collapsible` *(default true)*, `Collapsed` | Folding by pressing the header |
| `Tier`, `PaidOnly`, `LockText`, `LockHint` | Lock the section: one overlay with an icon, the wording and a hint covers its rows |

`Tab:Select()`, `Tab:SetTitle(text)`, `Tab:SetBadge(value)` (a number, a short word, `true` for a dot, `nil` to clear), `Tab:SetVisible(bool)`, `Tab:ShowWhen(source, value)`, `Tab:Notice({ Title, Content, Kind, Dismissible })` (a callout at the top of the page), `Tab:EmptyState({ Icon, Title, Text, Kind = "error", Button })`, `Tab:About(options)`. `Section:SetTitle(text)`, `:SetBadge(value)`, `:SetCollapsed(bool)`, `:SetVisible(bool)`, `:SetEnabled(bool)`, `:SelectTab(name)`, `:ShowWhen(source, value)`, `:EnableWhen(source, value)`, `:Destroy()`.

`Section:Group({ Columns = 2 })` returns a holder that takes the same element calls as the section and puts two or three controls side by side on one line. On a narrow page they stack.

```lua
local pair = Section:Group({ Columns = 2 })
pair:Toggle({ Title = "Auto farm", Flag = "AutoFarm" })
pair:Toggle({ Title = "Auto sell", Flag = "AutoSell" })
```

Elements can be added to a tab directly; they go into an untitled flat section.

## Elements

Every element is created on a tab or section and returns a handle.

**Options every element takes:** `Title` (required, except Divider, Code, Image, Buttons, Space, Table and Stats), `Description`, `Icon` (a leading icon), `Flag` (saves the value in configs), `Callback`, `Tier` (a tier name), `PaidOnly`, `LockText`, `Badge` (`"New"`, `"Beta"`, `"Risky"`, `"Paid"`, any text, or `{ Text, Color }`), `Info` (a longer explanation behind an info icon), `Requires` (executor functions the row needs; without them it is locked with their names), `Style` (a look; see [styles.md](styles.md)), `Tooltip` (hover text, or `{ Title, Text, Key, Style }`), `Spotlight` (`{ Title, Text, Id }`: a one-time pointer at a new feature), `Menu` (a list of `{ Title, Icon, Callback, Danger, Disabled }` or `{ Divider = true }`, opened by a right-click or a long press on the row), and the switches `Visible`, `Disabled`, `ShowWhen` and `EnableWhen`.

**Every handle has:** `Get()`, `Set(value)`, `Changed` (a signal), `SetTitle(text)`, `SetDescription(text)`, `SetDisabled(bool)`, `SetEnabled(bool)`, `SetVisible(bool)`, `Lock(text, icon)`, `Unlock()`, `IsLocked()`, `ShowWhen(source, value)` (visible only while another element, or its Flag, has that value; `value` may be a function), `EnableWhen(source, value)` (the same, greyed instead of hidden), `Spotlight(options)`, `Destroy()`, `Frame`, `Kind`, `Flag`.

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
| `MenuButton` | `Text` (the button's word, *default* `"Actions"`), `Icon`, `Items` (as for `Menu`), `Width` | none |
| `Link` | `Url`, `Icon`. Roblox cannot open a browser, so a press copies the address; without a clipboard the address shows in a box to select | the address |
| `List` | `Values` (plain values or `{ Text, Value, Icon, Description }`), `Default`, `Multi`, `Search`, `Reorder` (drag the items into order), `Height` *(default 200, then it scrolls)* | one value; a list with `Multi`; every value in order with `Reorder` |
| `Tags` | `Default` (a list), `Placeholder`, `Suggestions`, `Max`, `AllowDuplicates`. Enter adds what was typed; the × on a chip removes it | a list of words |
| `PlayerList` | `Actions` (`{ Title, Icon, Callback(player) }` buttons on every row), `Search` *(default true)*, `ShowSelf`, `Selectable`, `Height` *(default 240)*. Follows players joining and leaving | the picked player's name with `Selectable` |
| `Stat` | `Value`, `Unit`, `Change` (a leading `+` is green and `-` red, unless `Kind` is `"good"`, `"bad"` or `"neutral"`), `Icon`, `Style` (`"Card"` or `"Plain"`); `SetUnit(text)`, `SetChange(text, kind)` | the value |
| `Stats` | `Items` (`{ Title, Value, Unit, Change, Kind, Icon, Key }`), `Columns` *(default 3)*. As many tiles to a line as fit; `Set(key, value)`, `Get(key)`, `Items[key]` | none |
| `Graph` | `Values`, `Max` (how many it keeps, *default 40*), `Min` and `Ceiling` (a fixed range; otherwise it fits the values), `Height` *(default 80)*, `Suffix` or `Format` (for the newest value beside the title), `Role` (the colour), `Style` (`"Line"`, `"Area"` or `"Bars"`); `Push(value)`, `Clear()` | the values |
| `Log` | `Height` *(default 180)*, `MaxLines` *(default 200)*, `Timestamps` *(default true)*, `EmptyText`; `Add(text, level)`, `Info(text)`, `Success(text)`, `Warn(text)`, `Error(text)`, `Clear()`. Has level filters and copy and clear buttons; follows new lines while scrolled to the bottom | every line as text |
| `Banner` | `Text`, `Image` (any image source; without one it sits on a tint of the accent), `Height` *(default 132)*, `Button = { Title, Callback }`; `SetText(text)`, `SetImage(source)` | none |

### Notes

- **Toggle add-ons.** `Keybind = { Default = Enum.KeyCode.F, Mode = "Toggle" or "Hold", Flag = "FlyKey" }` puts a key chip beside the switch; `Color = { Default = Color3, Alpha = true, Flag = "FlyColor", Callback = fn }` puts a colour swatch there. They are reachable as `handle.Keybind` and `handle.Color`.
- **Toggle motion.** A switch's thumb stretches toward its new side and settles with a small overshoot; a checkbox's tick pops in. With reduced motion on, both change at once.
- **Toggle outline.** `Outline = false` turns the hover outline off for one toggle; `OutlineColor = Color3` gives it its own colour.
- **Slider tooltip.** `Tooltip = false` hides the value bubble for one slider; `TooltipStyle` picks its shape. The bubble never covers the slider's value box.
- **Keybind.** Press the chip, then a key. Escape cancels, Backspace clears. A key typed into a text box is ignored.
- **ColorPicker.** `Set` takes a `Color3` or a hex string. The Callback runs when a drag ends, not on every move.
- **Narrow rows.** In a two-column page or on a phone, a slider's track, a dropdown, an input and a segmented control move under their title at full width, so a title is never squeezed.
- **Row menus.** `Menu` items run their `Callback` and close the menu. A `Danger` item is drawn in red; a `Disabled` one is greyed and ignores presses.

## Sheets and the quick bar

```lua
local options = Window:Sheet({ Title = "Auto farm", Width = 340 })
options:Slider({ Title = "Radius", Min = 10, Max = 200, Flag = "FarmRadius" })
options:Toggle({ Title = "Skip bosses", Flag = "SkipBosses" })
Section:Button({ Title = "Farm options", Callback = function()
	options:Open()
end })
```

A sheet slides over the page from the window's right edge and holds a feature's extra options without leaving the tab. It takes element calls like a section (they go to its first section) and `Sheet:Section(options)` for more. `Open()`, `Close()`, `IsOpen`, `SetTitle(text)` and `Destroy()`; a press on the dimmed page behind it closes it.

```lua
local bar = Window:QuickBar({ Items = { "AutoFarm", "Fly", { Title = "Stop all", Icon = "octagon-x", Callback = stopAll } } })
bar:Add("InfiniteJump")
```

The quick bar is a small floating bar of the hub's most used switches and buttons. It stays on screen when the window is hidden, so a phone player can flip a feature without opening the hub, and it is dragged by its grip. An item is a toggle's flag or handle (the bar shows its state and a press flips it) or `{ Title, Icon, Callback }` for a button. `SetVisible(bool)` and `Destroy()`.

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
| `Default` | A card with the icon in a tinted square and a countdown rail |
| `Timer` | The seconds left in a small pill |
| `Compact` | One line in a pill: icon and title |
| `Banner` | A tinted band across the top, with the countdown on it |
| `Progress` | A bar the hub fills; stays until `Done`. `Indeterminate = true` runs it before there is an amount |
| `Accent` | A card whose colour runs down its whole left edge, following the rounded corners |
| `Glass` | A frosted, see-through card |
| `Achievement` | A large icon disc, for a reward or milestone |
| `Snackbar` | A dark one-line bar with its first action in the accent colour |
| `Island` | A dark capsule at the top centre, apart from the stack, in light themes too |

Every notice returns a handle with `Dismiss`, `SetTitle`, `SetContent`, `SetProgress` and `Done` (also called `Complete`). `Close = false` hides a notice's ×, which otherwise shows on hover, and always on touch screens.

Hovering a notice pauses its countdown, and dragging it sideways dismisses it. When more than `MaxVisible` are waiting, a pill says how many more there are. With `NotificationCenter = true` the window keeps the last 50 behind a bell in the top bar.

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

`KeySystem = { Discord = "https://discord.gg/yourcode" }` puts a round invite button under the key prompt. `Profile = { Discord = "https://discord.gg/yourcode" }` puts one on the profile card. Each is separate and off unless given; `false` leaves it out. Pressing the button, or the words beside it on the key prompt, opens the invite in the player's Discord app when the executor has `request` and Discord is running. Otherwise it copies the invite, and the player is told which happened. The button shows the Discord logo; pass `{ Link, Icon, Label }` instead of a string to use your own mark or change the prompt's label.

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

A watermark field may also be any text or a function returning text. Both overlays can be dragged. `Style` picks a look: Card, Pill, Accent or Minimal for the watermark; Card, Glass or Minimal for the keybind list. `Watermark = true` and `KeybindList = true` on `CreateWindow` make the same overlays; a table there is passed as their options.
