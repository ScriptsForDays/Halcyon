# Icons

Anything that takes an `Icon` accepts:

| Value | Meaning |
|---|---|
| `"rocket"` | An icon from the default pack (Lucide) |
| `"solar:rocket-bold"` | An icon from a named pack |
| `123456789` | Your own image asset id |
| `"rbxassetid://123456789"` | A content string, used as it is |

## Packs

| Prefix | Set | Names |
|---|---|---|
| `lucide:` (default) | [Lucide](https://lucide.dev/icons/) | `house`, `chevron-down`, `circle-alert` |
| `solar:` | [Solar](https://icones.js.org/collection/solar) | name plus style: `home-bold`, `home-linear`, `home-bold-duotone` |
| `geist:` | [Geist](https://vercel.com/geist/icons) | `accessibility`, `arrow-up` |
| `craft:` | [Craft Icons](https://www.figma.com/community/file/1415718327120418204) | name plus style: `rocket-stroke` |
| `gravity:` | [Gravity UI](https://gravity-ui.com/icons) | `alarm`, `alarm-fill` |
| `sfsymbols:` | [SF Symbols](https://developer.apple.com/sf-symbols/) | camelCase: `house`, `houseAndFlagFill` |

The Roblox uploads of these sets come from [Footagesus/Icons](https://github.com/Footagesus/Icons) (MIT). Browse that repository for the exact names in each pack.

## How they load

- **143 Lucide icons are built in** (`src/Core/IconData.luau`): everything the library draws itself plus common hub icons. They need no network and work in Studio.
- **Everything else loads on first use.** The first icon you name from a pack fetches that pack once, pinned to a fixed commit, and caches it at `Halcyon/cache/icons/<pack>.lua`. Later runs read the cache.
- **Pack files are read as data, never run.** The library pulls names and ids out with patterns, so a pack file cannot execute code in your hub.
- **If a pack cannot be fetched** (no HTTP, as in Studio, or the network is down) its icons stay blank, one warning is printed, and labels still show. Do not build a control that is an icon alone from a remote pack.

To make another pack the default for names without a prefix:

```lua
Halcyon:CreateWindow({ Title = "My Hub", IconPack = "solar" })
Halcyon:SetIconPack("solar")
```

## Your own pack

```lua
Halcyon:AddIconPack("brand", {
	logo = 123456789, -- an asset id
	wordmark = "rbxassetid://987654321",
	spark = { Image = "rbxassetid://555", RectOffset = Vector2.new(0, 128), RectSize = Vector2.new(128, 128) }, -- a sprite
})

Window:Tab({ Title = "Shop", Icon = "brand:logo" })
```

Icons are tinted by the theme, so upload them white on transparent.

## Adding to the built-in set

Edit the name list in `tools/build-icons.mjs` and run it. A name the Lucide pack does not contain fails the build.

```bash
node tools/build-icons.mjs
```
