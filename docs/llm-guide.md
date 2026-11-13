# Building a hub with Halcyon: a guide for AI assistants

LLM.txt says what Halcyon can do. This guide is about judgement: which of those things to use for a given hub, and which to leave out. It does not prescribe a layout. Every rule comes with its reason, so you can tell when a case calls for something else.

The most common failure is not a broken script. It is a hub that uses everything: every element has its own look, every tab has a notice, every toggle sends a notification, and the player can't find the one switch they came for. Halcyon's defaults are already designed to look finished. Your job is mostly to organise the hub's real features well.

## 1. Start from the features, not the components

Before writing any UI, list what the script actually does and what the player needs to control. For each feature, write down:

- whether it is a thing that stays on (a mode) or a thing that happens once (an action);
- what values it needs, and their range;
- whether the player will want it the same way next time (a saved setting).

Only then pick controls. A hub with six features needs six or so rows plus settings, not thirty.

## 2. Choose the control from the value

| The value is | Use | Why not the alternatives |
|---|---|---|
| On or off, and stays that way | Toggle | A Button forgets its state; a Dropdown hides a binary choice |
| Something that happens now | Button | A Toggle that turns itself off is confusing |
| A destructive action | Button with `Variant = "Danger"` and `Confirm` or `Hold` | One mis-click should never wipe progress |
| One of 2-4 short modes | Segmented | All options visible, one tap |
| One of 2-6 options with longer names | Radio | Visible and readable; Segmented truncates long names |
| One of many (7+), or a dynamic list (players, maps) | Dropdown | Lists that size need search and scrolling |
| Several independent picks of one kind | Checklist (few) or Dropdown with `Multi` (many) | One row instead of a toggle per item |
| A few visual choices | Tiles | Icons help recognition; more than ~9 becomes a wall |
| A number in a known range | Slider | Drag for feel, type for precision (the value box) |
| A small exact count | Stepper | Precise without typing |
| Free text, or a number with no sensible range | Input | Everything else needs a bounded set |
| A key the player picks | Keybind, or a Toggle's `Keybind` add-on | The add-on keeps the key beside the feature it controls |
| A colour | ColorPicker, or a Toggle's `Color` add-on | Same reason |
| Read-only state | Status, Progress, Countdown, Label | Nothing to press, so don't make it look pressable |
| Read-only figures (FPS, coins per hour) | Stat, or Stats for several | Big numbers read at a glance; labels in a row don't |
| A number's recent history | Graph | A trend is the point; one number hides it |
| What the hub did, line by line | Log | Notices vanish; a log can be scrolled, filtered and copied |
| Read-only rows of data | Table | Labels in a loop can't sort or align |
| Picks the player should see without opening anything, or an order | List (`Reorder` for priorities) | A Dropdown hides the choices; toggles per item waste rows |
| Words the player types and keeps (a whitelist) | Tags | An Input holds one value; Tags hold a list |
| Something to do to a player | PlayerList with `Actions` | Picking a name in a Dropdown and then pressing a button is two steps |
| A few actions on one thing | MenuButton, or a row's `Menu` | Five buttons for one config crowd the section |
| An address to open elsewhere | Link | Roblox can't open browsers; Link copies and says so |
| Help and explanations | `Info` on the row, Accordion, Paragraph | Keep long text out of row descriptions |

A row description is one short line about what the feature does or a caveat ("Kept after respawning"). If you need a paragraph, use `Info` or an Accordion. Don't write descriptions that explain the control itself ("Turn this on to enable flying"); the title and the switch already say it.

## 3. Organise tabs and sections

**Tabs are the player's mental map.** Group by what the player is trying to do: Player, Combat, Farming, Visuals, Teleports, Settings. Avoid tabs named after implementation ("Main", "Misc", "Scripts", "Other").

- **How many tabs:** 3-7 feature tabs plus Settings is comfortable. Beyond about 8, the sidebar scrolls and players stop exploring. Merge thin tabs, or use sidebar `Group` headings to cluster them (Features / Utility / Info).
- **A tab with one section and two rows** belongs inside a neighbour.
- **How full a section gets:** about 3-8 rows. Past that, split by sub-purpose (Movement / Character), use `Tabs` inside the section for parallel variants (Aim settings for Players / NPCs), or set `MaxHeight` for long uniform lists.
- **Two columns:** use `Side = "Right"` when two sections are peers on the same tab. Don't use it to balance heights artificially; on phones everything stacks in creation order anyway, so put the more important section first.
- **Order rows by frequency of use:** the main switch first, its tuning after it. Pair a feature's tuning with `ShowWhen` so options appear only when they apply (a Speed slider shown only while Fly is on). This keeps the page short without hiding anything permanently.
- **Lock rather than remove.** If a feature needs a paid key or an executor function, keep the row and lock it (`PaidOnly`, `Tier`, `Requires`). Players then know it exists and why they can't use it.
- **Short pairs share a line.** `Section:Group({ Columns = 2 })` fits two short toggles side by side (Auto farm / Auto sell). Keep sliders, lists and long titles on their own lines.
- **A feature with many settings** can keep its main switch on the tab and its tuning in a `Window:Sheet`, opened by a button beside it, so the page stays short.

## 4. Decide what to save

Give a `Flag` to settings a player would want restored: speeds, toggles for passive features, colours, keybinds, selected modes. Leave Flags off:

- one-shot actions (Buttons have no value anyway);
- toggles that start something risky or costly the moment they turn on (auto-buy, server-hopping), unless the hub warns about it. `LoadAutoload` runs every flagged Callback.
- values that only make sense in one server (a selected player).

Call `Window:SettingsTab()` (or `ConfigSection`) so players can save and load configs. Call `LoadAutoload()` once, last.

## 5. Feedback: say less, but say what matters

- **Notify** on results the player can't otherwise see: a config saved or failed, a teleport failed, a long task finished, a key about to expire.
- **Don't notify** on every toggle. The switch moving is the feedback.
- **For work that takes time,** use a Progress notice, `Button:SetLoading`, or `Window:Loading` during setup, driven by real progress. Never a timer pretending to be progress.
- **For errors,** say what failed and what to do ("Teleport failed: the destination is locked for your level"), not "An error occurred".
- **Tab notices, spotlights and badges** are for genuinely new or important things. One spotlight per release is plenty. A notice on every tab gets ignored.

## 6. Looks: defaults first

Halcyon's defaults are a complete, consistent design. Customising looks is optional, and the more scattered it is, the worse the hub looks.

- **Prefer no look options at all.** If the developer wants a different feel, one `Preset` (or one `Styles` table on the window) restyles everything consistently.
- **Avoid per-element `Style`** except where an element has a different job. Examples: a Danger button, a Labelled toggle for a setting where "ON/OFF" matters, a Chips dropdown for a filter that is changed often.
- **Theme:** pick one theme or let players choose in Settings. Don't hardcode accent colours on individual elements; the theme system recolours everything consistently, and literal colours break when players switch themes.
- **Don't stack effects.** Glass window, gradient accent, glow toggles and sweep buttons together read as noise. Pick one signature.

## 7. Phones and small screens

- **Touch targets** are handled by Halcyon (44 px on touch). Don't shrink rows with `Density = "Compact"` for a hub aimed at mobile players.
- **Two-column layouts** stack on narrow screens. Write the sections in the order a phone user should see them.
- **Phones have no keyboard.** Hover tooltips become long-press, and keybinds are irrelevant on touch. Don't put essential information only in a tooltip.
- **On phones** the window always has an open button, so don't build your own.

## 8. Key system and access

- **One tier:** if the hub only distinguishes "has a key" from "doesn't", use the single-tier shorthand (`Keys`/`Remote` at the top level).
- **Several tiers:** Keyless (no key), Free (a key earned through an ad link), Paid. Lock features to tiers with `Tier`/`PaidOnly` on the narrowest container that fits: a whole tab, a section, or a row.
- **Verifying keys:** keys must be checked by the developer's own server or the ad service's API via `Validate`, `Remote` or `Confirm`. Never invent an endpoint or a key algorithm, and never call a client-side check secure.
- **Discord:** add the `Discord` invite on the key prompt when getting a key involves a community step; on the profile card when the hub has an active community. Use the developer's real invite.

## 9. What to leave out

Unless the developer asks for it, leave out:

- `UpdateLog`, `Changelog` and `Loading`, unless the hub has releases or a real setup phase to show;
- `CommandPalette` and `Snap`, unless the hub is large (Ctrl+K pays off at around 30+ rows);
- Personalise and the theme builder, which are optional extras in Settings;
- Watermark and KeybindList, which are overlays some players dislike. Offer them as Settings toggles rather than forcing them on;
- `NotificationCenter` and `Blur`, unless the hub sends notices worth reading later or the developer wants the blur;
- a QuickBar, unless the hub targets phones and has two or three features players flip constantly.

To remove a built-in part the developer doesn't want, set its switch to `false` (`Search = false`, `Close = false`) rather than hiding instances.

## 10. Examples of over-building, and the fix

**Too many tabs.** "Main, Player, Movement, Character, Combat, Aim, ESP, Visuals, World, Teleports, Misc, Credits, Settings."
- Merge Player, Movement and Character into one Player tab with sections.
- Merge Aim and ESP into Combat and Visuals.
- Fold Credits into an `About` section in Settings, and drop Misc by placing its rows where they belong.

**A toggle per item.** Fifteen toggles: "Collect Gold", "Collect Gems", and so on.
- Use one Checklist with `SelectAll`, or a `Multi` Dropdown, plus one "Auto collect" toggle.

**Styled to death.** Every toggle a different `Style`, three Label callouts per section, a notice on every tab.
- Remove the per-element styles and keep one Warning callout where something is genuinely risky.

**Notification spam.** `Notify` in every Callback.
- Remove them; keep notices for failures and finished long tasks.

**Faked loading.** A Loading screen with `task.wait(3)`.
- Drop it, or report real steps (asset preload, remote discovery) with `SetProgress`.

## 11. A checklist before you hand the code over

- [ ] Every row maps to a real feature, and each tab name describes its contents.
- [ ] Controls match their values (section 2); destructive actions confirm.
- [ ] Flags only on settings worth restoring; `LoadAutoload()` is last.
- [ ] Features turn off cleanly when their toggle turns off, and `OnUnload` restores what the hub changed.
- [ ] Notifications only for results and failures.
- [ ] Looks are defaults, one Preset, or one window `Styles` table, not scattered per element.
- [ ] Nothing in this hub uses an option, method, look or icon not listed in LLM.txt.
