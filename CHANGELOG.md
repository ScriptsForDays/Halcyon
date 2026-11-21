# Changelog

## 2.3.1

- `Translate = true` on CreateWindow shows the hub's own text in the player's language: tab and section names, row titles and descriptions, options, placeholders, menus, dialogs and notices. Lines go to Google's free translate service about forty at a time, with numbers swapped for markers, and are saved per language in the workspace, so each is fetched once. `Fixes` sets your own wording, `Skip` leaves names as written and `Service` plugs in another translator. Values, flags and callbacks keep the text as written, search matches both, and a failing service leaves the text as it was. The hub's name, `Skip` entries, gaming terms such as Ping and Keyless, acronyms and code-like words stay as written, a few common hub words (Dashboard, Memory, News, Features, Free, Paid) have set translations, and Halcyon's own Settings rows are never sent.
- Switching language in Settings now re-translates a translated hub's text at once.
- Longer words in other languages no longer run out of their boxes: log filters and bar-chart legends wrap, a donut's legend keeps to its column, stat labels keep to their card, and a filled button's label keeps to the button.
- Item names, rarities, key tier names, tile titles, section titles and a section's inner tabs shrink a little before they are cut off.
- A placeholder longer than its input box shrinks, then ends in an ellipsis, instead of running into the box's edge.
- A typo's suggested option name no longer depends on table order, and two swapped letters count as one slip.

## 2.3.0

- The resize grip keeps the window's bottom-right corner under the pointer. It grew the window by twice the pointer's travel, which only held while the window was centred; after a drag, or with a saved position, the corner ran away at double speed.
- Values: `SetSilent`, `Reset` and `GetDefault` on every control; `Window:GetValues`, `SetValues`, `ResetValues` and `Undo`.
- Share codes: `ExportConfig` and `ImportConfig` move every flagged setting as one line of text, with copy and paste rows in the config block. They work on executors without file functions.
- `Configs = { PerGame = "Place" | "Universe" }` keeps configs and autoload per game.
- A failing callback shows its reason under its row and is kept in `Window.Errors`; a button whose callback yields shows its spinner until it returns.
- `Debug = true` warns about option names Halcyon doesn't know, with the name it guesses you meant, and about misspelt looks and themes.
- Halcyon's own text can be translated: `Language` (with "auto"), `Strings`, a Language row in Settings, and packs for Brazilian Portuguese, Spanish, Vietnamese, Indonesian, Russian, Turkish, French and German.
- Notices: `Countdown` picks a bar, the card's outline draining back to the top centre (Edge), a ring round the close button, a top line or none. `Id` updates a notice in place, repeats fold into one with a count, `Image` and `Avatar` show a picture, `OnClick` and `OnDismiss` report what the player did, `Stack = "Deck"` piles notices, and `ClearNotifications` dismisses them all.
- New elements: Viewport, Gauge, Knob, Chart (donut, pie, line, bars), ItemGrid and Waypoints.
- Keybind `Modifiers` for Ctrl, Shift and Alt combinations; a `Keybind` on Button; Toggle `Exclusive` groups and `Confirm`; Input `Validate` and `SetError`.
- `Tab:Page` and `Section:Page` open sub-pages with a breadcrumb, a back arrow and Escape.
- `Favourites = true` lets players star rows into a Favourites tab of live copies (`Favourite = true` on a row starts it there); `TabReorder = true` lets them drag, pin and move tabs.
- `PopOut = true` on a section moves its rows into a floating panel that stays up while the hub is hidden and resizes from its corner; a section background moves into the panel and fills it.
- Search marks the matched words, counts matches per section and in the box, and Enter or the arrow keys step through them with a light that runs round the row.
- `Background` puts a moving Aurora, Glow, Gradient, Mesh, Pattern or Image behind the window or inside a section, driven by tweens and paused while hidden. Glow follows the pointer, `Sheen = true` sends a band of light across, `Vignette` darkens the rim, and `SeeThrough` lets the background show through the cards.
- `UpdateCheck` tells players when a newer version is out; `SupportPanel` and `ErrorsPanel` (also rows in Settings) help with bug reports.
- `Halcyon:RegisterElement` adds your own element kinds, `Halcyon:Build` makes a whole hub from one table, and `dist/Halcyon.types.luau` gives editors the types.
- LLM.txt and docs/llm-guide.md cover all of the above, with a task index, recipes, common mistakes and the messages Halcyon prints.

## 2.2.1

- Text no longer starts small and jumps to size when a window opens. The library starts loading its font as soon as it loads, and `CreateWindow` waits for it (at most two seconds, and only the first time).
- The default open look is now Rise, a short slide. Pop scaled the whole window, which redrew every label at each step; it is still there for hubs that choose it. The motion now starts once the first frame is drawn, so a long first layout no longer swallows it.
- With a Pill or Chip minimise style, the menu key folds the window to the pill or chip and back instead of hiding it.
- Rows build their lock overlay only when they are first locked or disabled, which cut about a quarter of the instances in a large hub.
- The navigation keeps tabs under their sidebar heading and the update log last, even when a hub builds its tabs a frame apart.
- The example hub builds its first tab at once and the rest over the next few frames, so it opens without a long freeze.

## 2.2.0

- Every built-in part turns on or off with `true` or `false` on `CreateWindow`, and `Window:Set` and `Window:Get` flip and read them live. New switches: `Close`, `Drag`, `Tooltips`, `Animations`, `Blur`, `Watermark`, `KeybindList`, `SettingsTab` and `NotificationCenter`. `Minimize` and `Resize` are the plain names for `Minimizable` and `Resizable`, which still work. `Halcyon:GetSwitches()` lists them.
- Tabs, sections and rows take `Visible`, `Disabled`, `ShowWhen` and `EnableWhen` when they are made.
- Header styles: `HeaderStyle = "Tall"`, `"Wordmark"` or `"Sidebar"` (a big logo above the sidebar), with a `Logo` option. `Icon = false` and `TopbarImage = false` leave those pictures out.
- New elements: List, Tags, PlayerList, MenuButton, Stat and Stats, Graph, Log, Banner and Link. Any row takes a right-click `Menu`. `Section:Group` puts two or three controls on one line, `Window:Sheet` slides a panel over the page, and `Window:QuickBar` keeps chosen toggles on screen while the window is hidden.
- Notices: the Accent colour runs down the card's whole edge, hovering pauses the countdown, a sideways drag dismisses, a pill counts the ones waiting, and `NotificationCenter = true` keeps a history behind a bell. Glass, Island, Snackbar, Banner, Progress and Timer were redrawn.
- A `Panel` section look and a `Text` tab marker.
- Shorter labels and descriptions in the settings tab, config section, theme builder and dialogs.
- On a narrow window the top-bar search folds to its magnifier, and a long title ends in an ellipsis instead of being cut off.
- Popups place themselves from their set width, so a dropdown never opens off to the side for a frame.
- Notices: the countdown is now a rounded rail inside the card instead of a line on its bottom edge. Banner notices count down on their top strip, Progress notices show only their own bar, and the Accent stripe sits inside the card's outline. The stack keeps 16 px from the screen edge.
- The Discord button's label on the key prompt can be pressed too.
- A folded Accent section no longer shows a stub of its stripe, which showed on older releases in the update log.
- Button rows size each button to its words and wrap onto a second line instead of clipping long labels.

## 2.1.0

- Images from a URL or a workspace file anywhere the UI takes an image, loaded through `getcustomasset` and cached. `Halcyon:Image` for your own use.
- `TopbarImage` puts a picture before the window title in six shapes: Circle, Rounded, Square, Squircle, Ring and Badge.
- Discord invite buttons for the key prompt (`KeySystem.Discord`) and the profile card (`Profile.Discord`), each separate and off unless given. A press opens the invite in the Discord app when it's running and copies the link when it isn't.
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
