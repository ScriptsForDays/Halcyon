-- Dividers, minimising, notices, configs, badges, locks and the other
-- window behaviour added after the first release.
local Internal = Halcyon.Internal
local Hairline, library = Internal.Hairline, Internal.library
local UserInputService = game:GetService("UserInputService")

local function press(surface, x, y)
	local input = { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(x, y, 0) }
	surface.InputBegan:Fire(input)
	return input
end

local function dialogCard()
	for _, gui in Stub.guis() do
		local found = Stub.byName(gui, "Dialog")
		if found then
			return found
		end
	end
	return nil
end

Stub.genv.availableFunction = function() end
local window = Halcyon:CreateWindow({ Title = "Polish Hub", Folder = "PolishHub", Version = "v2" })
local tab = window:Tab({ Title = "Player", Icon = "user" })
local section = tab:Section({ Title = "Movement" })

-- Dividers are zero-thickness outlines whose weight follows the scale.
local seam = window.topbarSeam
Stub.equal(seam.Size.Y.Offset, 0, "a divider frame has no thickness of its own")
local stroke = seam:FindFirstChildOfClass("UIStroke")
Stub.check(stroke ~= nil and stroke.Thickness == 1, "the line is drawn by an outline one pixel wide")
window:SetScale(1.25)
Stub.equal(stroke.Thickness, 1 / 1.25, "the outline thins as the interface grows, so it stays one pixel on screen")
window:SetScale(1)
Stub.equal(Hairline.scale, 1, "the line scale follows the window scale")

-- The window sits on whole pixels and above game screens.
local shown = window.root.AbsoluteSize
local corner = window.root.Position.X.Offset - window.root.Size.X.Offset / 2
Stub.equal(corner, math.round(corner), "the window's left edge sits on a whole pixel")
Stub.equal(window.gui.DisplayOrder, 2147483000, "the window draws above the game's own screens")
Stub.check(shown ~= nil, "the window has a size")

-- Folding to the top bar hides the seam and swaps the icon.
window:Minimize(true)
Stub.check(not seam.Visible, "the top bar's seam hides while the window is folded")
Stub.equal(window.minimizeGlyph:GetAttribute("HalcyonIcon"), "maximize-2", "the minimise button shows a maximise icon while folded")
window:Minimize(false)
Stub.check(seam.Visible, "the seam returns when the window unfolds")
Stub.equal(window.minimizeGlyph:GetAttribute("HalcyonIcon"), "minus", "the minimise icon returns")

-- Position and size are remembered.
window.placed = Vector2.new(40, 30)
window.size = Vector2.new(700, 460)
window:layout()
window:savePreferences()
Stub.advance(1)
local saved = Stub.files["Halcyon/PolishHub/settings.json"]
Stub.check(saved ~= nil and string.find(saved, '"position":{"x":40,"y":30}', 1, true) ~= nil, "the window's position is saved")
Stub.check(string.find(saved, '"size":{"x":700,"y":460}', 1, true) ~= nil, "the window's size is saved")

Stub.check(window.versionTag.Visible and window.versionTag.Text == "v2", "the version shows beside the title")

-- Row badges and info tips.
local badged = section:Toggle({ Title = "Fly", Badge = "New", Info = "Hold Space to rise." })
Stub.check(Stub.byText(badged.Frame, "NEW") ~= nil, "a row shows its badge")
local info = Stub.byName(badged.Frame, "Info")
info.MouseEnter:Fire()
Stub.check(library.popup ~= nil and Stub.byText(library.popup.frame, "Hold Space to rise.") ~= nil, "hovering the info icon shows the explanation")
info.MouseLeave:Fire()
Stub.equal(library.popup, nil, "leaving the info icon hides it")
Stub.click(info)
Stub.check(library.popup ~= nil, "a tap opens the explanation on touch screens")
Stub.click(info)
Stub.equal(library.popup, nil, "a second tap closes it")
local custom = section:Toggle({ Title = "Speed", Badge = { Text = "Hot", Color = Color3.fromRGB(255, 80, 0) } })
Stub.equal(Stub.byText(custom.Frame, "HOT").TextColor3, Color3.fromRGB(255, 80, 0), "a badge can carry its own colour")

-- Executor checks.
local needs = section:Toggle({ Title = "Silent aim", Requires = { "missingFunction" } })
Stub.check(needs:IsLocked() and Stub.byText(needs.Frame, "Needs missingFunction") ~= nil, "a row whose executor function is missing is locked and says which")
Stub.check(not section:Toggle({ Title = "Fine", Requires = { "availableFunction" } }):IsLocked(), "a row whose functions exist stays open")
local missing = window:Require({ "availableFunction", "missingFunction", "bad name()" })
Stub.equal(table.concat(missing, ","), "missingFunction,bad name()", "Require lists what is missing, and names that are not plain identifiers count as missing")
window:SetTier("Paid")
Stub.check(needs:IsLocked(), "a missing function keeps the row locked whatever the tier")

-- Lock shimmer.
local paid = section:Toggle({ Title = "Kill aura", PaidOnly = true })
Stub.check(Stub.byName(paid.Frame, "Shimmer") ~= nil, "a locked row's badge shimmers")
Stub.equal(Stub.byName(badged.Frame, "Effects"), nil, "an open row carries no shimmer layer")

tab:SetBadge(3)
Stub.check(Stub.byText(tab.button, "3") ~= nil, "a tab shows its count")
tab:SetBadge(nil)
Stub.equal(Stub.byName(tab.button, "Badge"), nil, "clearing the badge removes it")

-- Profile tier icon.
local tierBadge = Stub.byName(window.root, "TierBadge")
Stub.equal(tierBadge:FindFirstChildOfClass("ImageLabel"):GetAttribute("HalcyonIcon"), "lock-open", "Keyless shows an open lock")

-- Notification styles.
Halcyon:Notify({ Title = "Timed", Style = "Timer", Duration = 4 })
Stub.flush()
local timer = Stub.byName(library.toasts.holder, "Timer")
Stub.equal(timer.Text, "4s", "a Timer notice shows the seconds left")
Stub.advance(2.05)
Stub.equal(timer.Text, "2s", "and counts down")
Stub.advance(3)
local compact = Halcyon:Notify({ Title = "Saved", Content = "Not shown", Style = "Compact" })
Stub.check(Stub.byText(library.toasts.holder, "Not shown") == nil, "a Compact notice is one line")
compact.Dismiss()
local banner = Halcyon:Notify({ Title = "Update", Style = "Banner" })
Stub.check(Stub.byName(library.toasts.holder, "Strip") ~= nil, "a Banner notice has a coloured strip")
banner.Dismiss()
local job = Halcyon:Notify({ Title = "Downloading", Content = "0 of 10", Style = "Progress" })
Stub.advance(10)
Stub.equal(#library.toasts.active, 1, "a Progress notice stays until the work is done")
job.SetProgress(0.5)
Stub.equal(Stub.byName(library.toasts.holder, "Fill").Size.X.Scale, 0.5, "the bar shows the progress given")
job.SetContent("5 of 10")
Stub.check(Stub.byText(library.toasts.holder, "5 of 10") ~= nil, "the content can change")
job.Done("Downloaded")
Stub.check(Stub.byText(library.toasts.holder, "Downloaded") ~= nil, "Done shows the finished title")
Stub.advance(3)
Stub.equal(#library.toasts.active, 0, "a finished Progress notice leaves by itself")
Halcyon:SetNotificationDefaults({ Style = "Compact" })
local plain = Halcyon:Notify({ Title = "Plain", Content = "Hidden by the default style" })
Stub.check(Stub.byText(library.toasts.holder, "Hidden by the default style") == nil, "the default style applies to notices that name none")
plain.Dismiss()
Halcyon:SetNotificationDefaults({ Style = "Default" })

-- The config section.
local configTab = window:Tab({ Title = "Configs", Icon = "save" })
local block = window:ConfigSection(configTab)
local changes = {}
window.ConfigChanged:Connect(function(action, name)
	table.insert(changes, action .. ":" .. tostring(name))
end)
local nameBox = Stub.byName(Stub.byText(block.root, "Config name").Parent.Parent.Parent, "Input")
nameBox.Text = "farm"
nameBox.FocusLost:Fire(true)
Stub.click(Stub.byText(block.root, "Save").Parent.Parent.Parent.Parent)
Stub.check(window:ConfigExists("farm"), "Save writes the named config")
Stub.equal(changes[#changes], "save:farm", "ConfigChanged reports the save")
local before = #changes
Stub.click(Stub.byText(block.root, "Save").Parent.Parent.Parent.Parent)
Stub.check(dialogCard() ~= nil and Stub.byText(dialogCard(), 'Overwrite "farm"?') ~= nil, "saving over an existing config asks first")
Stub.equal(#changes, before, "nothing is written until the player agrees")
Stub.click(Stub.byText(dialogCard(), "Overwrite"))
Stub.equal(changes[#changes], "save:farm", "agreeing overwrites it")
Stub.click(Stub.byText(block.root, "Delete").Parent.Parent.Parent.Parent)
Stub.click(Stub.byText(dialogCard(), "Delete"))
Stub.check(not window:ConfigExists("farm"), "Delete removes it after asking")

-- A slider for the scale applies on release; unload asks before it removes anything.
local settings = window:SettingsTab({ ScaleControl = "Slider" })
Stub.check(Stub.find(settings.page, function(instance)
	return instance.Name == "Track"
end) ~= nil, "ScaleControl = Slider shows a slider for the interface scale")
local unloaded = false
window.OnUnload:Connect(function()
	unloaded = true
end)
Stub.click(Stub.byText(settings.page, "Unload"))
Stub.check(not unloaded and dialogCard() ~= nil, "Unload asks first")
Stub.click(Stub.byText(dialogCard(), "Keep"))
Stub.check(not unloaded, "Keep leaves the script running")
Stub.click(Stub.byText(settings.page, "Unload"))
Stub.click(Stub.byText(dialogCard(), "Unload"))
Stub.check(unloaded, "confirming unloads it")

local quick = Halcyon:CreateWindow({ Title = "Quick Hub", Folder = "QuickHub", ConfirmUnload = false, LockShimmer = false, SavePreferences = false })
local quickTab = quick:Tab({ Title = "Combat" })
Stub.equal(Stub.byName(quickTab:Toggle({ Title = "Locked", PaidOnly = true }).Frame, "Shimmer"), nil, "LockShimmer = false turns the shimmer off")
local gone = false
quick.OnUnload:Connect(function()
	gone = true
end)
Stub.click(Stub.byText(quick:SettingsTab().page, "Unload"))
Stub.check(gone, "ConfirmUnload = false unloads at once")

UserInputService.InputEnded:Fire(press(UserInputService, 0, 0))
Halcyon:Unload()
Stub.equal(#Stub.guis(), 0, "everything removed")
