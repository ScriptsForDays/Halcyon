-- Notice looks, hover tips, spotlights, HUD looks and the command palette.
local Internal = Halcyon.Internal
local library = Internal.library
local UserInputService = game:GetService("UserInputService")
-- Longer than the pause before a tip shows.
local TIP_WAIT = 0.6

local function overlayFind(name)
	for _, gui in Stub.guis() do
		local found = Stub.byName(gui, name)
		if found then
			return found
		end
	end
	return nil
end

local window = Halcyon:CreateWindow({ Title = "Feedback Hub", Folder = "FeedbackHub", CommandPalette = true })
local farm = window:Tab({ Title = "Farming", Icon = "leaf" })
local fields = farm:Section({ Title = "Fields" })
local harvest = fields:Toggle({ Title = "Harvest wheat", Tooltip = { Title = "Harvest", Text = "Collects ripe wheat.", Key = "H" } })
local plain = fields:Toggle({ Title = "Water crops", Tooltip = "Waters everything nearby." })
local speed = fields:Slider({ Title = "Speed", Tooltip = false, Min = 1, Max = 5 })
local shop = window:Tab({ Title = "Shop", Icon = "shopping-cart" })
local buy = shop:Section({ Title = "Seeds" }):Button({ Title = "Buy seeds", Spotlight = { Title = "New", Text = "Seeds restock every hour.", Id = "seeds-v2" } })

-- Notice looks.
for _, look in Halcyon:GetStyles("Notification") do
	local notice = window:Notify({ Title = look .. " notice", Content = "Body", Style = look, Duration = 0 })
	Stub.check(notice ~= nil and not notice.done, look .. " notice shows")
	notice.Dismiss()
end
local undone = false
window:Notify({ Title = "Item sold", Style = "Snackbar", Actions = { { Title = "Undo", Callback = function()
	undone = true
end } } })
Stub.click(Stub.byText(overlayFind("Holder"), "Undo"))
Stub.flush()
Stub.check(undone, "a snackbar's word runs its action")
local isle = window:Notify({ Title = "Connected", Style = "Island" })
Stub.check(Stub.byText(overlayFind("Island"), "Connected") ~= nil, "an island notice sits in its own place at the top")
isle.Dismiss()

-- Hover tips.
local row = harvest.Frame
row.MouseEnter:Fire()
Stub.check(overlayFind("Tooltip") == nil, "a tip waits before showing")
Stub.advance(TIP_WAIT)
local tip = overlayFind("Tooltip")
Stub.check(tip ~= nil, "a tip shows after a pause over the row")
Stub.check(Stub.byText(tip, "Collects ripe wheat.") ~= nil and Stub.byText(tip, "H") ~= nil, "it shows its title, text and key")
row.MouseLeave:Fire()
Stub.check(overlayFind("Tooltip") == nil, "and hides when the pointer leaves")
plain.Frame.MouseEnter:Fire()
plain.Frame.MouseLeave:Fire()
Stub.advance(TIP_WAIT)
Stub.check(overlayFind("Tooltip") == nil, "a pointer that passes straight through shows no tip")
speed.Frame.MouseEnter:Fire()
Stub.advance(TIP_WAIT)
Stub.check(overlayFind("Tooltip") == nil, "a slider's Tooltip = false is its value bubble, not a hover tip")
speed.Frame.MouseLeave:Fire()

-- Spotlight: shown on its tab, dismissed once, remembered.
Stub.flush()
Stub.check(Stub.byName(buy.Frame, "Spotlight") ~= nil, "a spotlight puts a dot on its row")
Stub.check(overlayFind("Callout") == nil, "its callout waits until the row's tab is open")
window:SelectTab(shop)
Stub.flush()
local callout = overlayFind("Callout")
Stub.check(callout ~= nil, "the callout shows once the tab opens")
Stub.click(Stub.byName(callout, "GotIt"))
Stub.check(Stub.byName(buy.Frame, "Spotlight") == nil and overlayFind("Callout") == nil, "Got it removes the dot and the callout")
Stub.check(window.seenSpotlights["seeds-v2"], "the dismissal is remembered")
Stub.advance(1)
local saved = Stub.files["Halcyon/FeedbackHub/settings.json"]
Stub.check(saved ~= nil and string.find(saved, "seeds-v2", 1, true) ~= nil, "and saved with the preferences")

-- HUD looks.
for _, look in Halcyon:GetStyles("Watermark") do
	local mark = window:Watermark({ Style = look, Fields = { "Title", "FPS" } })
	Stub.check(mark.Frame ~= nil, "watermark look " .. look .. " builds")
	mark:Destroy()
end
for _, look in Halcyon:GetStyles("KeybindList") do
	local list = window:KeybindList({ Style = look })
	Stub.check(list.Frame ~= nil, "keybind list look " .. look .. " builds")
	list:Destroy()
end

-- Command palette.
local palette = window:OpenPalette()
Stub.check(overlayFind("Palette") ~= nil, "the palette opens over the screen")
Stub.equal(#palette.results(), 2, "with nothing typed it lists the tabs")
palette.box.Text = "wat"
Stub.equal(palette.results()[1].title, "Water crops", "typing lists matching rows")
palette.box.Text = "wheat"
palette.box.FocusLost:Fire(true)
Stub.flush()
Stub.check(overlayFind("Palette") == nil, "Enter jumps and closes it")
Stub.check(window.selected == farm, "and opens the row's tab")
palette = window:OpenPalette()
palette.box.Text = "zzz"
Stub.equal(#palette.results(), 0, "a query with no match lists nothing")
UserInputService.InputBegan:Fire({ KeyCode = Enum.KeyCode.Escape, UserInputType = Enum.UserInputType.Keyboard }, false)
Stub.check(overlayFind("Palette") == nil, "Escape closes it")

window:Unload()
local again = Halcyon:CreateWindow({ Title = "Feedback Hub", Folder = "FeedbackHub" })
local returning = again:Tab({ Title = "Shop" }):Section({ Title = "Seeds" }):Button({ Title = "Buy seeds", Spotlight = { Text = "Again", Id = "seeds-v2" } })
Stub.flush()
Stub.check(Stub.byName(returning.Frame, "Spotlight") == nil, "a dismissed spotlight never returns")
again:Unload()
Stub.check(library.palette == nil, "nothing of the palette outlives the window")
