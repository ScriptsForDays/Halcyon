# Halcyon

A UI library for Roblox script hubs. One file, loaded with `loadstring`, that gives you a window with tabs, sections and fifteen controls, a key system with tiers, saved configs, ten themes, six icon packs, and a layout that reflows from a desktop monitor down to a phone.

![The Halcyon example hub](assets/hero.jpg)

## Try it

Run the example in your executor. It opens a hub that uses every control:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ScriptsForDays/Halcyon/main/example/Example.luau"))()
```

The example asks for a key first. **Free** needs none; to see the paid tier, enter `HALCYON-PAID`.

## Use it

```lua
local Halcyon = loadstring(game:HttpGet("https://raw.githubusercontent.com/ScriptsForDays/Halcyon/main/dist/Halcyon.luau"))()

local Window = Halcyon:CreateWindow({
	Title = "My Hub",
	Subtitle = "Universal",
	Version = "v1.0.0", -- the tag beside the title; ShowVersion = false hides it
	Icon = "sparkles",
	Folder = "MyHub", -- configs and settings save under Halcyon/MyHub/
})

local Player = Window:Tab({ Title = "Player", Icon = "user" })
local Movement = Player:Section({ Title = "Movement" })

Movement:Toggle({
	Title = "Fly",
	Description = "WASD to steer, Space and Shift to climb",
	Flag = "Fly", -- saved in configs; also Window.Flags.Fly
	Callback = function(enabled)
		-- your code
	end,
})

Movement:Slider({
	Title = "Walk speed",
	Min = 16,
	Max = 120,
	Default = 32,
	Flag = "WalkSpeed",
	Callback = function(speed) end,
})

Window:SettingsTab() -- themes, menu key, configs, unload
Window:LoadAutoload() -- loads the config the player marked, if any
```

`RightShift` shows and hides the window. On a phone, a round button takes its place.

## What is in it

| | |
|---|---|
| **Buttons** | Filled, outline and danger buttons with a Sweep, Ripple, Lift or Glow effect |
| **Controls** | Button, Toggle (switch or checkbox, three thumb shapes, an optional keybind and colour), Slider (single or range, with a value tooltip), Dropdown (single, multi, searchable), Input, Keybind, ColorPicker (with alpha), Segmented, Stepper, Progress, Paragraph, Label, Divider, Code, Image |
| **Layout** | Four navigation styles (Sidebar, Rail, Top, Dock), three section styles (Card, Outlined, Flat), one or two columns, collapsible sections and sidebar groups, three ways to minimise |
| **Key system** | Tiers such as Free and Paid, or your own; listed keys, your own validator or your own server; ad-service confirmation for free keys; saved keys with an expiry countdown; rows and whole sections locked to a tier or to paid keys |
| **Feedback** | Notifications with a countdown bar and buttons, dialogs, a watermark, a keybind list |
| **Saving** | Configs for every flagged control, autoload, and the player's own interface choices |
| **Looks** | Inter by default, ten themes, your own themes, an accent override, a soft window shadow, six icon packs, your own font |
| **Profile** | Avatar (headshot or 3D viewport), name, tier, executor, date and time, with an anonymous mode |
| **Search** | One box that filters every tab and opens the first one with a match |

![Controls: checkbox, multi dropdown, notifications](assets/controls.jpg)

## Turning things on and off

Most features are one option. Leave it out for the default, or set it to `false`:

```lua
Halcyon:CreateWindow({
	Title = "My Hub",
	ShowVersion = false, -- no version tag beside the title
	Shadow = false, -- no soft shadow under the window
	ButtonEffect = "None", -- or "Sweep" (default), "Ripple", "Lift", "Glow"
	Search = false, -- no search box
	Profile = false, -- no profile card
	Resizable = false, -- no resize grip
	Minimizable = false, -- no minimise button
	CollapsibleGroups = false, -- sidebar group headings do not fold
	SliderTooltips = false, -- no value bubble while dragging a slider
	ToggleOutline = false, -- no outline around a toggle on hover
	SavePreferences = false, -- do not remember the player's interface choices
})

Window:SettingsTab({ Accent = false, Scale = false, Unload = false }) -- leave rows out of the Settings tab
```

The full list is in [docs/api.md](docs/api.md).

## Key system

```lua
local Window = Halcyon:CreateWindow({
	Title = "My Hub",
	KeySystem = {
		Note = "Keys are posted in our Discord.",
		Tiers = {
			{ Name = "Free", Keys = { "FREE-2026" }, Link = "https://example.com/get-key", Duration = 86400 },
			{
				Name = "Paid",
				Link = "https://example.com/buy",
				Validate = function(key)
					return myServerSaysValid(key), "That key is not active."
				end,
			},
		},
	},
})
if not Window then
	return -- the player closed the prompt
end

Tab:Toggle({ Title = "Kill aura", PaidOnly = true }) -- locked unless the key is paid
Tab:Section({ Title = "Raids", PaidOnly = true, LockHint = "Buy a key in our Discord" }) -- one overlay over the section
```

![The key prompt](assets/key-system.jpg)

![A locked section and a locked row](assets/locked.jpg)

A key with a `Duration` shows a countdown on the profile card; `ShowExpiry = false` in the `KeySystem` table hides it.

Free keys can be tied to an ad service, rows can be locked to a tier, and the lock wording is yours to set. A window with no key system reports its tier as `Keyless`. See [docs/key-system.md](docs/key-system.md).

> **A key prompt in a script is not security.** It runs on the player's machine, so anyone who reads the script can skip it. Halcyon's prompt is a gate for honest users. To protect a script, have your server hand it out only after the key is checked there.

## Themes

Midnight, Onyx, Rose, Aqua, Ember, Forest, Amethyst, Crimson, Glacier and Daylight are built in. Every one keeps its text at a contrast of 4.5 or more.

```lua
Halcyon:SetTheme("Rose")
Halcyon:SetAccent(Color3.fromRGB(255, 120, 40)) -- recolour the accent of any theme
Halcyon:AddTheme({ Name = "Mine", Base = "Midnight", accent = Color3.fromRGB(80, 220, 160) })
```

![Rose, Aqua, Amethyst and Daylight](assets/themes.jpg)

More in [docs/themes.md](docs/themes.md).

## Icons

Any `Icon` takes a Lucide name. Prefix a pack to use another set:

```lua
Icon = "rocket" -- Lucide
Icon = "solar:rocket-bold" -- Solar
Icon = "geist:arrow-up" -- Geist; also craft:, gravity:, sfsymbols:
Icon = 123456789 -- your own asset id
```

143 Lucide icons ship inside the library and draw at once. The full packs load on first use and are cached on disk. More in [docs/icons.md](docs/icons.md).

## Phones and small screens

Below 560 px of window width the sidebar becomes a strip of tabs, two columns fold into one, and wide controls drop under their titles. Touch targets grow to 40 px or more, and text never goes below 12 px. Nothing is hover-only.

<img src="assets/mobile.jpg" alt="Halcyon at phone width" width="360">

![Rail and Dock navigation](assets/navigation.jpg)

## Details

![A slider tooltip and locked rows](assets/details.jpg)

- Running your hub twice replaces the first window instead of stacking a second.
- `Window:Unload()` removes every instance and connection the library made. `Window.OnUnload` is where your hub stops its own features.
- Without file functions (some executors, and Studio) nothing is saved, and the Settings tab says so. Nothing pretends to have saved.
- No per-frame work: dragging and sliders follow input events, and one loop a second drives every clock.

## Documentation

- [docs/api.md](docs/api.md): every option and method
- [docs/key-system.md](docs/key-system.md): tiers, ad services, paid locks, your own server
- [docs/themes.md](docs/themes.md): palettes and custom themes
- [docs/icons.md](docs/icons.md): packs and custom icons
- [LLM.txt](LLM.txt): the whole API in one file, written for AI coding assistants

## In Roblox Studio

1. In **Explorer**, under **ReplicatedStorage**, add a **ModuleScript** named `Halcyon` and paste in all of `dist/Halcyon.luau`.
2. Under **StarterPlayer > StarterPlayerScripts**, add a **LocalScript** and paste in `example/Example.luau`.
3. Press **Play**.

Studio has no file functions and cannot fetch the full icon packs, so saving is off there and only the built-in Lucide icons draw.

## Development

```bash
node tools/bundle.mjs
```

```bash
node tools/test.mjs
```

`src/` holds the modules; `tools/bundle.mjs` joins them into `dist/Halcyon.luau`. The tests run headless under the standalone [`luau`](https://github.com/luau-lang/luau/releases) binary against engine stubs, and cover values, callbacks, saved data, key checks and unload. They cannot see pixels: the screenshots here come from Roblox Studio, and behaviour inside each executor is yours to confirm.

## License

[MIT](LICENSE). Icon credits are in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
