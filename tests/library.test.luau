local Internal = Halcyon.Internal
local Theme, library = Internal.Theme, Internal.library
local UserInputService = game:GetService("UserInputService")
local baseline = Stub.inputConnections()

local function press(surface, x, y)
	local input = { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(x, y, 0) }
	surface.InputBegan:Fire(input)
	return input
end

local function move(x, y)
	UserInputService.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(x, y, 0) })
end

local function option(text)
	local label = Stub.byText(library.popup.frame, text)
	return label and label.Parent
end

-- Window and tabs.
local window = Halcyon:CreateWindow({ Title = "Test Hub", Subtitle = "v1", Folder = "TestHub", Icon = "rocket", Tiers = { "Free", "Paid" }, Tier = "Free" })
Stub.check(window ~= nil, "window created")
Stub.equal(#Stub.guis(), 1, "one ScreenGui until something needs the overlay")
local tab = window:Tab({ Title = "Player", Icon = "user" })
local world = window:Tab({ Title = "World", Icon = "globe", Group = "Game" })
Stub.equal(window.selected, tab, "first tab is selected")
Stub.check(tab.page.Visible and not world.page.Visible, "only the selected page shows")
Stub.equal(window.activeStyle, "Sidebar", "sidebar by default on a wide screen")
Stub.check(pcall(window.Tab, window, {}) == false, "a tab without a Title is refused")

local section = tab:Section({ Title = "Movement" })

-- Toggle.
local flyCalls = {}
local fly = section:Toggle({
	Title = "Fly",
	Description = "WASD to steer",
	Flag = "Fly",
	Callback = function(on)
		table.insert(flyCalls, on)
	end,
})
Stub.equal(fly:Get(), false, "toggle starts off")
Stub.equal(#flyCalls, 0, "creating a toggle that is off runs nothing")
Stub.click(fly.Frame)
Stub.equal(fly:Get(), true, "press turns the toggle on")
Stub.equal(flyCalls[1], true, "toggle callback receives the value")
Stub.equal(window.Flags.Fly, fly, "flag registered on the window")
Stub.equal(fly.Kind, "Toggle", "handle knows its kind")

-- Hover outline: only while the pointer is on the switch itself.
local flySwitch = Stub.byName(fly.Frame, "Switch")
local ringStroke = Stub.byName(Stub.byName(fly.Frame, "Outline"), "Stroke")
Stub.equal(ringStroke.Transparency, 1, "the outline is hidden at rest")
fly.Frame.MouseEnter:Fire()
Stub.equal(ringStroke.Transparency, 1, "hovering the row beside the switch shows no outline")
flySwitch.MouseEnter:Fire()
Stub.equal(ringStroke.Transparency, 0, "hovering the switch shows its outline")
Stub.equal(ringStroke.Color, Theme.color("accent"), "the outline uses the accent by default")
Stub.equal(fly.Frame.BackgroundTransparency, 1, "hover never fills the whole row")
flySwitch.MouseLeave:Fire()
Stub.equal(ringStroke.Transparency, 1, "the outline hides when the pointer leaves")
window:SetToggleOutline(true, Color3.fromRGB(255, 200, 0))
flySwitch.MouseEnter:Fire()
Stub.equal(ringStroke.Color, Color3.fromRGB(255, 200, 0), "the outline colour can be set for the window")
flySwitch.MouseLeave:Fire()
window:SetToggleOutline(false)
flySwitch.MouseEnter:Fire()
Stub.equal(ringStroke.Transparency, 1, "the outline can be turned off for the window")
flySwitch.MouseLeave:Fire()
window:SetToggleOutline(true, false)
local ownOutline = section:Toggle({ Title = "Own outline", OutlineColor = Color3.fromRGB(0, 255, 0) })
local plainToggle = section:Toggle({ Title = "No outline", Outline = false })
local ownStroke = Stub.byName(Stub.byName(ownOutline.Frame, "Outline"), "Stroke")
Stub.byName(ownOutline.Frame, "Switch").MouseEnter:Fire()
Stub.equal(ownStroke.Color, Color3.fromRGB(0, 255, 0), "a toggle can carry its own outline colour")
Stub.byName(plainToggle.Frame, "Switch").MouseEnter:Fire()
Stub.equal(ownStroke.Transparency, 1, "moving to another switch clears the last one even if its leave was missed")
Stub.equal(Stub.byName(Stub.byName(plainToggle.Frame, "Outline"), "Stroke").Transparency, 1, "Outline = false turns it off for one toggle")
ownOutline:Destroy()
plainToggle:Destroy()

local sprintCalls = 0
section:Toggle({
	Title = "Auto sprint",
	Default = true,
	Callback = function()
		sprintCalls += 1
	end,
})
Stub.equal(sprintCalls, 0, "a default-on toggle does not call back during creation")
Stub.flush()
Stub.equal(sprintCalls, 1, "a default-on toggle calls back once, deferred")

local ok, message = pcall(function()
	section:Toggle({ Title = "Duplicate", Flag = "Fly" })
end)
Stub.check(not ok and string.find(tostring(message), "already used", 1, true) ~= nil, "duplicate flag refused")
Stub.equal(Stub.byText(tab.page, "Duplicate"), nil, "a refused element leaves no row behind")
Stub.check(not pcall(function()
	section:Toggle({})
end), "an element without a Title is refused")

-- Slider.
local speeds = {}
local speed = section:Slider({
	Title = "Walk speed",
	Min = 16,
	Max = 100,
	Default = 16,
	Flag = "Speed",
	Callback = function(value)
		table.insert(speeds, value)
	end,
})
Stub.equal(#speeds, 0, "a slider default is only shown, never written")
speed:Set(50.4)
Stub.equal(speed:Get(), 50, "slider snaps to its step")
speed:Set(500)
Stub.equal(speed:Get(), 100, "slider clamps to its range")
local track, rail = Stub.byName(speed.Frame, "Track"), Stub.byName(speed.Frame, "Rail")
Stub.place(rail, 100, 10, 200, 4)
local held = press(track, 150, 12)
Stub.equal(speed:Get(), 37, "press sets the value from the pointer")
move(200, 12)
Stub.equal(speed:Get(), 58, "drag follows the pointer")
UserInputService.InputEnded:Fire(held)
move(300, 12)
Stub.equal(speed:Get(), 58, "moving after release changes nothing")
local readout = Stub.byName(speed.Frame, "Value")
readout.Text = "72"
readout.FocusLost:Fire(true)
Stub.equal(speed:Get(), 72, "typing a number sets the slider")

-- Slider tooltip.
local function sliderTips()
	local found = {}
	for _, child in library.overlay.popups:GetChildren() do
		if child.Name == "SliderTip" then
			table.insert(found, child)
		end
	end
	return found
end
Stub.check(#sliderTips() == 1 and not sliderTips()[1].Visible, "the slider tooltip hides when the drag ends")
held = press(track, 150, 12)
local bubble = sliderTips()[1]
Stub.check(bubble.Visible, "the tooltip shows while the slider is dragged")
Stub.equal(Stub.byName(bubble, "Value").Text, "37", "the tooltip shows the value")
Stub.equal(bubble.Position.X.Offset, 150, "the tooltip sits over the knob")
Stub.check(Stub.byName(bubble, "Arrow") ~= nil, "the default tooltip has an arrow")
UserInputService.InputEnded:Fire(held)

-- The tooltip never covers the value box. Beside the track it stops at the
-- rail's end; with the box right above the track it drops under the knob.
Stub.place(readout, 308, -2, 54, 28)
held = press(track, 300, 12)
local shifted = Stub.byName(bubble, "Bubble")
Stub.equal(shifted.AnchorPoint.Y, 0, "at the end of the track the tooltip drops below the knob rather than cover the value box")
UserInputService.InputEnded:Fire(held)
held = press(track, 200, 12)
Stub.equal(shifted.AnchorPoint.Y, 1, "in the middle of the track the tooltip sits above the knob")
local arrowReach = math.abs(shifted.Position.X.Offset)
Stub.check(arrowReach <= 8, "the arrow stays on the bubble's flat edge")
UserInputService.InputEnded:Fire(held)
held = press(track, 100, 12)
Stub.check(math.abs(shifted.Position.X.Offset) <= 8, "at the start of the track the arrow still lands on the flat edge")
UserInputService.InputEnded:Fire(held)
Stub.place(readout, 246, -24, 54, 28)
held = press(track, 300, 12)
Stub.equal(shifted.AnchorPoint.Y, 0, "the tooltip drops below the knob when the value box is above the track")
Stub.check(shifted.Position.Y.Offset > 0, "a dropped tooltip sits under the knob")
move(150, 12)
Stub.equal(shifted.AnchorPoint.Y, 1, "it returns above the knob once clear of the box")
UserInputService.InputEnded:Fire(held)
Stub.place(readout, 0, 0, 0, 0)
local quiet = section:Slider({ Title = "Quiet", Tooltip = false })
UserInputService.InputEnded:Fire(press(Stub.byName(quiet.Frame, "Track"), 0, 0))
Stub.equal(#sliderTips(), 1, "Tooltip = false gives a slider no tooltip")
window:SetSliderTooltips(true, "Plain")
UserInputService.InputEnded:Fire(press(track, 150, 12))
Stub.equal(#sliderTips(), 1, "changing the style replaces the tooltip")
Stub.equal(Stub.byName(sliderTips()[1], "Arrow"), nil, "the Plain style has no arrow")
window:SetSliderTooltips(false)
held = press(track, 200, 12)
Stub.check(not sliderTips()[1].Visible, "tooltips can be turned off for the whole window")
UserInputService.InputEnded:Fire(held)
window:SetSliderTooltips(true, "Rounded")
speed:Set(72)

local fine = section:Slider({ Title = "Fine", Min = 0, Max = 1, Step = 0.1, Default = 0.5 })
fine:Set(0.1 + 0.2)
Stub.equal(fine:Get(), 0.3, "decimal steps carry no float noise")
local range = section:Slider({ Title = "Distance", Min = 0, Max = 100, Range = true, Default = { 20, 60 } })
Stub.equal(range:Get()[1] + range:Get()[2], 80, "range slider holds two values")
range:Set({ 90, 10 })
Stub.equal(range:Get()[1], 10, "range values are ordered")

-- Dropdown.
local picks = {}
local part = section:Dropdown({
	Title = "Target part",
	Values = { "Head", "Torso", "Legs" },
	Flag = "Part",
	Callback = function(value)
		table.insert(picks, value)
	end,
})
Stub.equal(part:Get(), "Head", "single dropdown defaults to its first value")
Stub.click(part.Frame)
Stub.check(library.popup ~= nil, "dropdown opens a popup")
Stub.equal(#Stub.guis(), 2, "popup lives in the overlay ScreenGui")
Stub.click(option("Torso"))
Stub.equal(part:Get(), "Torso", "choosing an option sets the value")
Stub.equal(library.popup, nil, "single dropdown closes after a choice")
Stub.click(part.Frame)
Stub.click(part.Frame)
Stub.equal(library.popup, nil, "pressing the row again closes its popup")
part:Refresh({ "Arms", "Legs" })
Stub.equal(part:Get(), nil, "a value that is no longer offered is dropped")

local multi = section:Dropdown({ Title = "Show", Values = { "Names", "Boxes", "Health" }, Multi = true, Default = { "Boxes" } })
Stub.click(multi.Frame)
Stub.click(option("Names"))
Stub.check(library.popup ~= nil, "multi dropdown stays open")
Stub.equal(Stub.byName(option("Names"), "Mark").BackgroundTransparency, 0, "a picked option fills its box")
Stub.equal(Stub.byName(option("Health"), "Mark").BackgroundTransparency, 1, "an unpicked option keeps an empty box")
Stub.equal(table.concat(multi:Get(), ","), "Names,Boxes", "multi value keeps the order of Values")
Stub.click(option("Boxes"))
Stub.equal(table.concat(multi:Get(), ","), "Names", "choosing a picked option removes it")
press(UserInputService, 5, 5)
Stub.equal(library.popup, nil, "a press outside closes the popup")

-- Input.
local typed = {}
local name = section:Input({
	Title = "Player name",
	Flag = "Name",
	Callback = function(value)
		table.insert(typed, value)
	end,
})
local box = Stub.byName(name.Frame, "Input")
box.Text = "Builderman"
box.FocusLost:Fire(true)
Stub.equal(name:Get(), "Builderman", "input value follows typing")
Stub.equal(typed[1], "Builderman", "input callback runs when typing ends")
local amount = section:Input({ Title = "Amount", Numeric = true, Min = 0, Max = 10, Default = 5 })
amount:Set("abc")
Stub.equal(amount:Get(), 5, "numeric input keeps its value when the text is not a number")
amount:Set(99)
Stub.equal(amount:Get(), 10, "numeric input clamps")

-- Keybind.
local keyCalls = {}
local bind = section:Keybind({
	Title = "Dash",
	Default = Enum.KeyCode.F,
	Mode = "Toggle",
	Flag = "DashKey",
	Callback = function(active)
		table.insert(keyCalls, active)
	end,
})
Stub.key(Enum.KeyCode.F)
Stub.equal(keyCalls[1], true, "bound key runs the callback")
Stub.key(Enum.KeyCode.F, true)
Stub.equal(#keyCalls, 1, "a key typed into a text box is ignored")
Stub.click(Stub.byName(bind.Frame, "Key"))
Stub.check(library.listeningForKey, "pressing the chip starts listening")
Stub.key(Enum.KeyCode.G)
Stub.equal(bind:Get(), Enum.KeyCode.G, "next key press rebinds")
Stub.equal(#keyCalls, 1, "the rebinding press does not run the callback")
Stub.check(not library.listeningForKey, "listening ends after the rebind")
Stub.equal(bind:Encode(), "G", "keybind saves as the key name")
Stub.equal(bind:Decode("NotAKeyAtAll") ~= nil or true, true, "decode never errors")
Stub.equal(bind:Decode(""), nil, "an empty saved key loads as no key")

local combo = section:Toggle({ Title = "Noclip", Keybind = { Default = Enum.KeyCode.N, Flag = "NoclipKey" }, Color = { Default = Color3.fromRGB(255, 0, 0), Flag = "NoclipColor" } })
Stub.key(Enum.KeyCode.N)
Stub.equal(combo:Get(), true, "a toggle's keybind flips the toggle")
Stub.check(window.Flags.NoclipKey ~= nil and window.Flags.NoclipColor ~= nil, "add-on flags registered")
Stub.equal(window.Flags.NoclipColor:Encode(), "ff0000", "add-on colour encodes as hex")

-- Colour picker.
local colors = {}
local tint = section:ColorPicker({
	Title = "ESP colour",
	Default = Color3.fromRGB(0, 255, 0),
	Flag = "Tint",
	Callback = function(color)
		table.insert(colors, color)
	end,
})
Stub.equal(tint:Encode(), "00ff00", "colour encodes as hex")
tint:Set("3366ff")
Stub.equal(tint:Get(), Color3.fromRGB(51, 102, 255), "a hex string sets the colour")
Stub.equal(#colors, 1, "setting a colour runs the callback")
tint:Set("nonsense")
Stub.equal(#colors, 1, "an invalid hex is ignored")
Stub.click(Stub.byName(tint.Frame, "Swatch"))
Stub.check(library.popup ~= nil, "swatch opens the picker")
local shade = Stub.byName(library.popup.frame, "Shade")
Stub.place(shade, 0, 0, 100, 100)
local shadePress = press(shade, 100, 0)
Stub.equal(#colors, 1, "dragging the picker does not call back on every move")
UserInputService.InputEnded:Fire(shadePress)
Stub.equal(#colors, 2, "the callback runs when the drag ends")
Halcyon.Internal.library.popup.close()

-- Remaining elements.
local mode = section:Segmented({ Title = "Mode", Values = { "Legit", "Rage" }, Flag = "Mode" })
Stub.equal(mode:Get(), "Legit", "segmented defaults to the first value")
Stub.click(Stub.byText(mode.Frame, "Rage"))
Stub.equal(mode:Get(), "Rage", "pressing a segment selects it")
local count = section:Stepper({ Title = "Clones", Min = 0, Max = 3, Default = 3 })
Stub.click(Stub.byName(count.Frame, "plus"))
Stub.equal(count:Get(), 3, "stepper stops at its maximum")
Stub.click(Stub.byName(count.Frame, "minus"))
Stub.equal(count:Get(), 2, "stepper steps down")
local progress = section:Progress({ Title = "Farm", Value = 25 })
Stub.equal(Stub.byName(progress.Frame, "Value").Text, "25%", "progress shows a percentage")
local clicks = 0
local button = section:Button({
	Title = "Rejoin server",
	Callback = function()
		clicks += 1
	end,
})
Stub.click(button.Frame)
local filled = section:Button({
	Title = "Teleport",
	Variant = "Filled",
	Callback = function()
		clicks += 1
	end,
})
Stub.click(Stub.byName(filled.Frame, "Button"))
Stub.equal(clicks, 2, "both button variants run their callback")
Stub.check(Stub.byName(filled.Frame, "Sweep") ~= nil, "filled buttons sweep by default")
Stub.byName(filled.Frame, "Button").MouseEnter:Fire()
Stub.equal(Stub.byName(filled.Frame, "Sweep").Position.X.Scale, 1.3, "the sweep crosses the button on hover")
local lifted = section:Button({ Title = "Lifted", Variant = "Outline", Effect = "Lift" })
local liftedButton = Stub.byName(lifted.Frame, "Button")
liftedButton.MouseEnter:Fire()
Stub.equal(liftedButton:FindFirstChildOfClass("UIScale").Scale, 1.03, "Lift grows the button on hover")
local rippled = section:Button({ Title = "Rippled", Variant = "Filled", Effect = "Ripple" })
local rippledButton = Stub.byName(rippled.Frame, "Button")
rippledButton.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(4, 4, 0) })
Stub.equal(Stub.byName(rippledButton, "Ripple"), nil, "a ripple removes itself when it has spread")
Stub.equal(Stub.byName(section:Button({ Title = "Plain", Variant = "Filled", Effect = "None" }).Frame, "Effects"), nil, "Effect = None adds nothing")
lifted:Destroy()
rippled:Destroy()
local note = section:Paragraph({ Title = "About", Content = "First" })
note:Set("Second")
Stub.check(Stub.byText(note.Frame, "Second") ~= nil, "paragraph content updates")
section:Label("A quiet note")
section:Divider({ Title = "More" })
section:Image({ Image = 123, Height = 80 })
local code = section:Code({ Title = "Loader", Code = "print('hi')" })
Stub.click(Stub.byName(code.Frame, "Copy"))
Stub.equal(Stub.clipboard, "print('hi')", "code block copies its text")
local crashed = section:Button({
	Title = "Broken",
	Callback = function()
		error("boom")
	end,
})
Stub.click(crashed.Frame)
Stub.equal(#Stub.errors, 0, "a failing callback is caught")
Stub.check(string.find(Stub.warnings[#Stub.warnings], "Broken callback failed", 1, true) ~= nil, "a failing callback is reported by name")

-- Disabled and locked.
bind:SetDisabled(true)
Stub.key(Enum.KeyCode.G)
Stub.equal(#keyCalls, 1, "a disabled keybind does not fire")
bind:SetDisabled(false)
local vip = section:Toggle({ Title = "Kill aura", Tier = "Paid" })
Stub.check(vip:IsLocked(), "an element above the player's tier is locked")
Stub.check(Stub.byText(vip.Frame, "Requires Paid") ~= nil, "a locked row says what it needs")
Stub.check(window:SetTier("Paid") and not vip:IsLocked(), "raising the tier unlocks it")
Stub.equal(window:GetTier(), "Paid", "tier readable")
Stub.check(not window:SetTier("Gold"), "an unknown tier is refused")

-- Search.
world:Section({ Title = "Lighting" }):Toggle({ Title = "Fullbright" })
window:Search("walk")
Stub.check(speed.Frame.Visible and not fly.Frame.Visible, "search hides rows that do not match")
window:Search("fullbright")
Stub.equal(window.selected, world, "search opens the first tab with a match")
window:Search("zzz")
Stub.check(window.empty.Visible, "search with no match says so")
window:Search("")
Stub.check(fly.Frame.Visible and not window.empty.Visible, "clearing the search restores every row")
window:SelectTab(tab)
note:SetVisible(false)
window:Search("about")
Stub.check(not note.Frame.Visible, "a row hidden by the hub stays hidden during a search")
window:Search("")

-- Configs.
local savedTint = tint:Encode()
Stub.check(window:SaveConfig("main"), "config saved")
fly:Set(false)
speed:Set(20)
tint:Set("000000")
mode:Set("Legit")
bind:Set(nil)
local before = #flyCalls
local loaded, summary = window:LoadConfig("main")
Stub.check(loaded, "config loaded: " .. tostring(summary))
Stub.equal(fly:Get(), true, "toggle restored")
Stub.equal(speed:Get(), 72, "slider restored")
Stub.equal(tint:Encode(), savedTint, "colour restored")
Stub.equal(mode:Get(), "Rage", "segmented restored")
Stub.equal(bind:Get(), Enum.KeyCode.G, "keybind restored")
Stub.equal(#flyCalls, before + 1, "loading a config runs the callback of what it sets")
Stub.check(not window:SaveConfig("///"), "a config name with no usable characters is refused")
Stub.check(window:SetAutoload("main") and window:LoadAutoload(), "autoload config loads")

-- Themes.
Halcyon:SetTheme("Daylight")
Stub.equal(window.root.BackgroundColor3, Theme.palettes.Daylight.background, "theme switch recolours the window")
Halcyon:SetAccent(Color3.fromRGB(255, 0, 128))
Stub.equal(Theme.color("accent"), Color3.fromRGB(255, 0, 128), "accent override applied")
Halcyon:SetTheme("Midnight")
Stub.equal(Theme.color("accent"), Color3.fromRGB(255, 0, 128), "accent override survives a theme switch")
Halcyon:SetAccent(nil)
Stub.equal(Theme.color("accent"), Theme.palettes.Midnight.accent, "clearing the override restores the theme accent")

-- Navigation styles and reflow.
local right = tab:Section({ Title = "Extras", Side = "Right" })
Stub.equal(right.root.Parent, tab.right, "a right section sits in the right column on a wide window")
Stub.check(window:SetTabStyle("Dock"), "tab style changes")
Stub.equal(window.activeStyle, "Dock", "dock navigation active")
Stub.equal(window.selected, tab, "changing navigation keeps the selected tab")
Stub.check(not window:SetTabStyle("Nope"), "unknown tab style refused")
window:SetTabStyle("Sidebar")
Stub.viewport(390, 844)
Stub.equal(window.activeStyle, "Top", "a phone-width window swaps the sidebar for a tab strip")
Stub.equal(window.root.Size.X.Offset, 374, "window fits the phone with a margin")
Stub.equal(right.root.Parent, tab.left, "columns fold into one on a narrow window")
Stub.equal(fly:Get(), true, "reflow keeps element values")
Stub.viewport(1280, 720)
Stub.equal(window.activeStyle, "Sidebar", "sidebar returns on a wide screen")

-- Sidebar groups fold and unfold.
local heading = Stub.byText(window.root, "Game").Parent
Stub.equal(heading.ClassName, "TextButton", "a group heading can be pressed")
Stub.click(heading)
Stub.check(not world.button.Visible, "a folded group hides its tabs")
Stub.check(tab.button.Visible, "tabs outside the group stay")
Stub.click(Stub.byText(window.root, "Game").Parent)
Stub.check(world.button.Visible, "pressing the heading again unfolds the group")
window:SetGroupCollapsed("Game", true)
Stub.advance(1)
Stub.check(string.find(Stub.files["Halcyon/TestHub/settings.json"], '"collapsedGroups":["Game"]', 1, true) ~= nil, "folded groups are saved")
window:SetGroupCollapsed("Game", false)

-- Menu key, minimise, hide.
Stub.key(Enum.KeyCode.RightShift)
Stub.check(not window.root.Visible, "menu key hides the window")
Stub.key(Enum.KeyCode.RightShift)
Stub.check(window.root.Visible, "menu key shows it again")
window:Minimize(true)
Stub.equal(window.root.Size.Y.Offset, 48, "minimised window is the top bar alone")
window:Minimize(false)

-- Pill and Chip each stand in for the window and bring it back.
Stub.check(window:SetMinimizeStyle("Pill"), "minimise style changes")
window:Minimize(true)
Stub.check(not window.root.Visible and window.pill.Visible, "Pill swaps the window for a titled pill")
UserInputService.InputEnded:Fire(press(window.pill, 5, 5))
Stub.check(window.root.Visible and not window.pill.Visible, "pressing the pill brings the window back")
window:SetMinimizeStyle("Chip")
window:Minimize(true)
Stub.check(not window.root.Visible and window.openButton.Visible and not window.pill.Visible, "Chip swaps the window for the open button")
window:Hide()
Stub.check(not window.openButton.Visible, "hiding a minimised window hides its chip too")
window:Show()
Stub.check(window.openButton.Visible and not window.root.Visible, "showing it again returns the chip, not the window")
UserInputService.InputEnded:Fire(press(window.openButton, 5, 5))
Stub.check(window.root.Visible, "pressing the chip brings the window back")
Stub.check(not window:SetMinimizeStyle("Nope"), "unknown minimise style refused")
window:SetMinimizeStyle("Topbar")

-- Window shadow and the open tab's marker.
Stub.check(window.shadow ~= nil and #window.shadow:GetChildren() > 1, "the window has a shadow")
Stub.equal(window.shadow.Size, window.root.Size, "the shadow matches the window's size")
window:Hide()
Stub.check(not window.shadow.Visible, "the shadow hides with the window")
window:Show()
Stub.equal(window.uiScale.Scale, window.scale, "the open animation ends at the window's scale")
Stub.check(tab.bar.Visible and not world.bar.Visible, "only the open tab carries the accent marker")

-- Version tag and thumb shapes.
Stub.check(not window.versionTag.Visible, "no version tag unless the hub gives a version")
window:SetVersion("v2.1")
Stub.check(window.versionTag.Visible and window.versionTag.Text == "v2.1", "the version tag shows the version")
window:SetVersionVisible(false)
Stub.check(not window.versionTag.Visible, "the version tag can be turned off")
window:SetVersionVisible(true)
local oval = section:Toggle({ Title = "Oval thumb", Thumb = "Oval" })
local ovalThumb = Stub.byName(oval.Frame, "Thumb")
Stub.equal(ovalThumb.Size.X.Offset, 18, "a toggle can pick its thumb shape")
Stub.click(oval.Frame)
Stub.equal(ovalThumb.Size.X.Offset, 24, "the thumb stretches as it starts to move")
Stub.advance(0.2)
Stub.equal(ovalThumb.Size.X.Offset, 18, "the thumb settles back to its shape")
Stub.equal(ovalThumb.Position.X.Offset, 15, "the thumb rests against the far side when on")
oval:Destroy()

-- An empty checkbox draws no tick at all, not a hidden one.
local box = section:Toggle({ Title = "Show names", Style = "Checkbox" })
local tick = Stub.byName(Stub.byName(box.Frame, "Switch"), "Icon")
Stub.equal(tick.Size.X.Offset, 0, "an empty checkbox draws no mark")
Stub.click(box.Frame)
Stub.equal(tick.Size.X.Offset, 14, "a ticked checkbox grows its mark")
box:Destroy()

-- Notifications and dialogs.
Stub.advance(10)
Stub.equal(#library.toasts.active, 0, "earlier notices have gone")
for index = 1, 6 do
	Halcyon:Notify({ Title = "Notice " .. index, Duration = 2 })
end
Stub.equal(#library.toasts.active, 4, "four toasts show at once")
Stub.equal(#library.toasts.queue, 2, "the rest wait")
Stub.advance(2.1)
Stub.equal(#library.toasts.active, 2, "queued toasts appear as others leave")
Stub.advance(2.1)
Stub.equal(#library.toasts.active, 0, "toasts dismiss themselves")

-- Notification defaults, countdown bars and actions.
Halcyon:SetNotificationDefaults({ Duration = 1, Position = "TopLeft", MaxVisible = 2, Progress = true })
Stub.equal(library.toasts.holder.AnchorPoint, Vector2.new(0, 0), "the default position moves the stack")
local acted = false
Halcyon:Notify({
	Title = "Update ready",
	Actions = { {
		Title = "Install",
		Callback = function()
			acted = true
		end,
	} },
})
Stub.check(Stub.byName(library.toasts.holder, "Countdown") ~= nil, "a timed notice carries a countdown bar")
Stub.click(Stub.byText(library.toasts.holder, "Install"))
Stub.check(acted and #library.toasts.active == 0, "a notice's button runs its callback and dismisses the notice")
Halcyon:Notify("One")
Halcyon:Notify("Two")
Halcyon:Notify("Three")
Stub.equal(#library.toasts.queue, 1, "MaxVisible limits how many show at once")
Stub.advance(1.1)
Stub.equal(#library.toasts.active, 1, "the default duration applies to notices that give none")
Stub.advance(1.1)
local sticky = Halcyon:Notify({ Title = "Stays", Duration = 0, Progress = false })
Stub.advance(30)
Stub.check(#library.toasts.active == 1 and Stub.byName(library.toasts.holder, "Countdown") == nil, "Duration = 0 stays until dismissed and has no bar")
sticky.Dismiss()
Stub.advance(1)
local job = Halcyon:Notify({ Title = "Downloading", Style = "Progress", Duration = 10 })
Stub.check(Stub.byName(library.toasts.holder, "Countdown") == nil, "a progress notice shows its own bar and no countdown")
job.Dismiss()
Stub.advance(1)
local banner = Halcyon:Notify({ Title = "Update", Style = "Banner", Duration = 10 })
local band = Stub.byName(library.toasts.holder, "Band")
Stub.check(band ~= nil and Stub.byName(band, "Countdown") ~= nil, "a banner counts down along its band instead of a second bar")
banner.Dismiss()
Stub.advance(1)
Halcyon:SetNotificationDefaults({ Duration = 4, Position = "BottomRight", MaxVisible = 4 })
local answered = false
local dialog = window:Dialog({
	Title = "Delete config?",
	Content = "This cannot be undone.",
	Buttons = {
		{ Title = "Keep" },
		{
			Title = "Delete",
			Variant = "Danger",
			Callback = function()
				answered = true
			end,
		},
	},
})
Stub.click(Stub.byText(dialog.card, "Delete"))
Stub.check(answered and dialog.Closed, "dialog button runs its callback and closes the dialog")

-- Profile, settings tab, watermark, keybind list.
local settings = window:SettingsTab()
Stub.check(settings ~= nil and #window.tabs == 3, "settings tab added")
Stub.check(Stub.byText(window.root, "Tester") ~= nil, "profile shows the display name")
window:SetAnonymous(true)
Stub.check(Stub.byText(window.root, "Tester") == nil and Stub.byText(window.root, "Anonymous") ~= nil, "anonymous mode hides the name")
window:SetAnonymous(false)
local mark = window:Watermark({ Fields = { "Title", "Executor", "FPS" } })
Stub.check(string.find(Stub.byName(mark.Frame, "TextLabel").Text, "Test Hub  |  TestExecutor", 1, true) ~= nil, "watermark shows its fields")
local list = window:KeybindList()
Stub.check(Stub.byText(list.Frame, "Dash") ~= nil, "keybind list shows bound keys")
Stub.advance(1.1)

-- Preferences persist and a second run replaces the first.
window:SetTabStyle("Rail")
Stub.advance(1)
Stub.check(Stub.files["Halcyon/TestHub/settings.json"] ~= nil, "interface preferences saved")
local unloads = 0
window.OnUnload:Connect(function()
	unloads += 1
end)
local second = Halcyon:CreateWindow({ Title = "Test Hub", Folder = "TestHub" })
Stub.equal(unloads, 1, "running the hub again unloads the first window")
Stub.check(rawget(window.gui, "destroyed"), "the first window's ScreenGui is destroyed")
Stub.equal(second.tabStyle, "Rail", "saved preferences apply to the next run")
Stub.equal(#library.windows, 1, "one window registered")

-- Features a hub turns off with one false each.
local plain = Halcyon:CreateWindow({
	Title = "Plain Hub",
	Folder = "PlainHub",
	Search = false,
	Profile = false,
	Minimizable = false,
	CollapsibleGroups = false,
	CollapsedGroups = { "Folded" },
	SavePreferences = false,
})
plain:Tab({ Title = "First", Group = "Open" })
local folded = plain:Tab({ Title = "Second", Group = "Folded" })
Stub.check(not plain.searchFrame.Visible, "Search = false hides the search box")
Stub.equal(Halcyon:CreateWindow({ Title = "Flat Hub", Folder = "FlatHub", Shadow = false, SavePreferences = false }).shadow, nil, "Shadow = false draws no shadow")
Stub.check(not Stub.byName(plain.root, "minus").Visible, "Minimizable = false hides the minimise button")
Stub.equal(Stub.byText(plain.root, "Tester"), nil, "Profile = false leaves no profile card")
Stub.equal(Stub.byText(plain.root, "Open").Parent.ClassName, "Frame", "CollapsibleGroups = false makes headings plain")
Stub.check(not folded.button.Visible, "CollapsedGroups folds a group from the start")
local trimmed = plain:SettingsTab({ Theme = false, Accent = false, Navigation = false, Scale = false, ReduceMotion = false, Configs = false, Unload = false })
Stub.check(Stub.byText(trimmed.page, "Appearance") == nil, "a settings section with every row off is left out")
Stub.check(Stub.byText(trimmed.page, "Toggle key") ~= nil, "rows left on stay")
Stub.check(Stub.byText(trimmed.page, "Unload") == nil and Stub.byText(trimmed.page, "Configs") == nil, "Unload and Configs can be turned off")
plain:SetTabStyle("Dock")
Stub.advance(1)
Stub.equal(Stub.files["Halcyon/PlainHub/settings.json"], nil, "SavePreferences = false writes nothing")
plain:Unload()

-- Unload leaves nothing behind.
second:Tab({ Title = "Only" }):Keybind({ Title = "Key", Default = Enum.KeyCode.K })
Halcyon:Unload()
Stub.equal(Stub.inputConnections(), baseline, "unload releases every input connection")
Stub.equal(#Stub.guis(), 0, "unload destroys every ScreenGui")
Stub.equal(Stub.genv.HalcyonWindows.TestHub, nil, "unload clears the shared registry")
Stub.key(Enum.KeyCode.K)
Stub.equal(#Stub.errors, 0, "no thread errors")
