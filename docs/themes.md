# Themes

## Built in

`Midnight` (default), `Onyx`, `Rose`, `Aqua`, `Ember`, `Forest`, `Amethyst`, `Crimson`, `Glacier`, `Daylight`.

```lua
Halcyon:CreateWindow({ Title = "My Hub", Theme = "Aqua" })
Halcyon:SetTheme("Daylight") -- any time; everything on screen recolours
```

The player's choice in the Settings tab is saved and wins over the script's default on the next run.

## Accent

```lua
Halcyon:SetAccent(Color3.fromRGB(255, 120, 40)) -- laid over whichever theme is active
Halcyon:SetAccent(nil) -- back to the theme's own accent
```

The hover shade and the text colour drawn on the accent are worked out for you.

## Your own theme

A theme is sixteen colour roles. Start from an existing one and change what you need:

```lua
local ok, message = Halcyon:AddTheme({
	Name = "Mint",
	Base = "Midnight", -- every role you leave out comes from here
	accent = Color3.fromRGB(80, 220, 160),
	accentHover = Color3.fromRGB(120, 235, 185),
	onAccent = Color3.fromRGB(6, 26, 18),
})
Halcyon:SetTheme("Mint")
```

Or pass a palette straight to the window: `Theme = { Name = "Mint", Base = "Midnight", accent = … }`.

| Role | Used for |
|---|---|
| `background` | The window |
| `surface` | Popups, dialogs, notifications |
| `card` | Card sections |
| `raised` | Chips, inputs, selected tabs, rows in flat sections |
| `hover` | Hovered controls |
| `stroke` | Outlines, dividers, an empty slider rail |
| `text` | Titles and values |
| `textMuted` | Descriptions and quiet labels |
| `accent`, `accentHover` | On and selected states; the filled button |
| `onAccent` | Text and icons drawn on the accent |
| `focus` | Focus highlights |
| `success`, `warning`, `danger`, `info` | Notification kinds, the danger button |

`AddTheme` returns `ok, message`:

- **Refused** when a role is missing (and there is no `Base`), or when text would be unreadable: a contrast under 3 between `text` or `textMuted` and any of `background`, `surface`, `card`, `raised`, or between `onAccent` and `accent`.
- **Accepted with a warning** when that contrast is under 4.5, the level the built-in themes all meet.

Without a `Base`, give all sixteen roles.

## Font

The default is Inter, a typeface drawn for interfaces, at one weight heavier than usual so text stays clear over a bright or busy game.

```lua
Halcyon:CreateWindow({ Title = "My Hub", Font = Enum.Font.BuilderSans })
Halcyon:SetFont("rbxasset://fonts/families/Montserrat.json") -- for everything created afterwards
```

Set the font before building the window; text already on screen keeps the font it was made with.
