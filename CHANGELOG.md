# Changelog

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
