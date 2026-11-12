# Changelog

## 2.1.0

- Images from a URL or a workspace file anywhere the UI takes an image, loaded through `getcustomasset` and cached. `Halcyon:Image` for your own use.
- `TopbarImage` puts a picture before the window title in six shapes: Circle, Rounded, Square, Squircle, Ring and Badge.
- Discord invite buttons for the key prompt (`KeySystem.Discord`) and the profile card (`Profile.Discord`), each separate and off unless given.
- `UpdateLog`: a tab of releases with kind tags, search, filters, an unseen badge and an optional What's new popup. `Window:AddUpdate` adds releases later.

## 2.0.0

A look for every control, presets, and the UI pieces hub developers used to build by hand. Nothing changes until a hub opts in: the defaults draw as 1.0 did.

- **Style system.** Every kind of control registers named looks. Pick one per element (`Style`), per window (`Styles = {...}`), or with a preset (`Preset = "Classic" | "Minimal" | "Glass" | "Neon" | "Compact"`). Hubs can add their own looks (`AddStyle`) and presets (`AddPreset`). `Radius`, `Density` and `TextSize` retune the whole library.
- **Control looks.**
  - Toggle: 10 looks.
  - Slider: 7 looks, plus Prefix, Percent, Format, Display and DefaultMarker.
  - Button: 8 looks, 2 more effects (Press, Fill), Hold, Confirm, ShowDone and SetLoading.
  - Input: 4 looks, plus LeadingIcon, Clearable, Counter, Password and MultiLine.
  - Dropdown: Box, Minimal, Chips and Inline, with option icons, descriptions, headings, disabled options and player lists.
  - Keybind: 3 looks and a mode picker.
  - Colour picker: palette, recent colours and copy.
- **New controls:** Radio, Checklist, Chips, Tiles, Rating, Accordion, Status, Countdown, Table, DatePicker, Buttons (several in one row), Space and callout Labels. Paragraph takes an image and buttons, and Stepper can be dragged.
- **Window:**
  - Solid, Glass, Gradient and Image surfaces, with Transparency.
  - Open animations: Pop, Zoom, Rise, Drop, Slide and Unroll.
  - Page transitions and Mac-style dot controls.
  - Top-bar buttons, a sidebar toggle and width, edge snapping, and `SetEnabled`.
- **Navigation and sections:**
  - Tab markers: Bar, Pill, Underline, Dot, Glow and Fill.
  - Page headers and notices.
  - Search that matches tab names and marks the match.
  - Section looks: Glass, Accent, Inset and Header.
  - Tabs inside sections, header switches, `MaxHeight`, and `ShowWhen` dependencies.
- **Feedback:**
  - Hover tooltips on any row.
  - One-time spotlights.
  - Five notice looks (Accent, Glass, Achievement, Snackbar, Island) and an opt-in chime.
  - Watermark and keybind-list looks.
  - A Ctrl+K command palette.
  - Dialog buttons held back by a countdown, a Ghost button, and Escape to close.
- **Personalisation:**
  - Six new themes (OLED, Contrast, Sunset, Ocean, Aurora, Latte).
  - Players change font, text size, corners, spacing, transparency and notice position live, with their choices saved.
  - A theme builder with save, copy and import.
  - Gradient accent and colour-blind-friendly status colours.
  - A focus ring for gamepad and keyboard navigation.
- **Hub panels:** `Loading` (real progress only), `Changelog` (once per version), `About`, `EmptyState`, `Lock`/`Unlock`.
- **Rebuilding:** running `CreateWindow` again in the same session keeps the access the player was already given (`KeySystem.Reprompt = true` asks again).

## 1.0.0

First release.

- Window with four navigation styles (Sidebar, Rail, Top, Dock), three section styles, one or two columns, drag, resize, three minimise styles, a menu key and a touch open button.
- Fifteen elements: Button, Toggle, Slider, Dropdown, Input, Keybind, ColorPicker, Segmented, Stepper, Progress, Paragraph, Label, Divider, Code, Image.
- Slider value tooltip in four shapes; toggle hover outline with a custom colour; three toggle thumb shapes with a spring animation.
- Inter as the default font, one weight heavier for legibility over games.
- Button effects: Sweep, Ripple, Lift and Glow.
- A redesigned key prompt with tier cards, an icon field and a footer; key expiry on the cards and a countdown on the profile card, with `ShowExpiry` to hide them.
- One overlay with wording and a hint over locked sections and tabs.
- Divider lines drawn as outlines so they keep one weight at any scale and position; the window sits on whole pixels.
- The window draws at a DisplayOrder near the top of the range in the executor's hidden container, and remembers its position and size.
- Notification styles: Timer, Compact, Banner and Progress, with a handle to update a Progress notice.
- Lock badges centred beside their titles, an icon-only chip in narrow rows, a shimmer across locked rows and sections (`LockShimmer = false` turns it off).
- Two-step unload (`ConfirmUnload`, on by default), interface scale as a slider (`ScaleControl = "Slider"`), and a maximise icon while folded.
- `Window:ConfigSection` with an overwrite check and `ConfigChanged`; row `Badge`, `Info` and `Requires`; `Tab:SetBadge`; tier icons on the profile card.
- A Studio model build (`dist/Halcyon.rbxmx`) split under Studio's script size limit.
- Version tag beside the window title; a soft window shadow; an accent marker on the open tab; open animations for the window, popups and dialogs.
- Key system with ordered tiers, listed keys, validators, remote checks, ad-service confirmation, saved keys with expiry and an attempt lockout.
- `Keyless` tier for windows without a key system; rows locked by tier or to paid keys, with custom lock wording.
- Profile card with avatar, tier, executor and clock, and an anonymous mode.
- Search across every tab; collapsible sections and sidebar groups.
- Notifications with a countdown bar, action buttons, six positions and settable defaults; dialogs; watermark; keybind list.
- Configs with autoload; saved interface preferences.
- Ten themes, custom themes with a contrast check, accent override.
- Built-in Lucide icons and six icon packs loaded on demand.
