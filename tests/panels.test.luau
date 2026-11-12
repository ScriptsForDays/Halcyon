-- Loading screen, What's new, About, empty states, lock screen and dialog extras.
local UserInputService = game:GetService("UserInputService")

local function overlayFind(name)
	for _, gui in Stub.guis() do
		local found = Stub.byName(gui, name)
		if found then
			return found
		end
	end
	return nil
end

Stub.genv.setclipboard = function(text)
	Stub.clipboard = text
end
local window = Halcyon:CreateWindow({ Title = "Panel Hub", Folder = "PanelHub", Version = "2.1" })
local farm = window:Tab({ Title = "Farming" })

-- Loading screen: only real progress.
local loader = window:Loading({ Title = "Setting up", Text = "Finding the map" })
local screen = Stub.byName(window.body, "Loading")
Stub.check(screen ~= nil, "a loading screen covers the window")
local fill = Stub.byName(screen, "Fill")
Stub.advance(2)
Stub.equal(fill.Size.X.Scale, 0, "it does not move on its own")
loader.SetProgress(0.5, "Loading assets")
Stub.advance(1)
Stub.equal(fill.Size.X.Scale, 0.5, "it moves with the hub's progress")
Stub.check(Stub.byText(screen, "Loading assets") ~= nil, "and says what is happening")
loader.Done()
Stub.advance(1)
Stub.check(Stub.byName(window.body, "Loading") == nil, "Done removes it")

-- What's new: once per version.
local card = window:Changelog({ Entries = { { Kind = "New", Text = "Auto farm" }, { Kind = "Fixed", Text = "Teleport" }, "Faster menus" } })
Stub.check(card ~= nil and overlayFind("Dialog") ~= nil, "the changelog shows for a new version")
Stub.check(Stub.byText(overlayFind("Dialog"), "What's new in 2.1") ~= nil, "titled with the version")
UserInputService.InputBegan:Fire({ KeyCode = Enum.KeyCode.Escape, UserInputType = Enum.UserInputType.Keyboard }, false)
Stub.check(overlayFind("Dialog") == nil, "Escape closes it")
Stub.check(window:Changelog({ Entries = { "Again" } }) == nil, "it does not show again for the same version")
Stub.check(window:Changelog({ Entries = { "Forced" }, Force = true }) ~= nil, "unless forced")
overlayFind("Dialog"):Destroy()

-- About.
local about = farm:About({ Description = "Farms for you.", Credits = { { Name = "Nova", Role = "Scripting" } }, Discord = "https://discord.gg/example" })
Stub.check(Stub.byText(about.root, "Discord") ~= nil, "About lists the Discord link")
Stub.click(Stub.byText(about.root, "Discord"))
Stub.flush()
Stub.equal(Stub.clipboard, "https://discord.gg/example", "pressing a link copies it")

local empty = farm:EmptyState({ Title = "No crops found", Text = "Walk to a field first.", Button = { Title = "Refresh" } })
Stub.check(Stub.byText(farm.page, "No crops found") ~= nil, "an empty state shows on the tab")
empty:SetText("Still nothing", "Try another field.")
Stub.check(Stub.byText(farm.page, "Try another field.") ~= nil, "its words can change")
empty:Destroy()
Stub.check(Stub.byText(farm.page, "Still nothing") == nil, "and it can be removed")
local failed = farm:EmptyState({ Kind = "error", Text = "The server did not answer." })
Stub.check(Stub.byText(farm.page, "Something went wrong") ~= nil, "an error state has its own wording")
failed:Destroy()

-- Lock screen.
window:Lock({ Title = "Down for maintenance", Text = "Back soon." })
Stub.check(Stub.byName(window.body, "LockScreen") ~= nil, "Lock covers the window")
window:Lock("Updated message")
local locks = 0
for _, child in window.body:GetChildren() do
	if child.Name == "LockScreen" then
		locks += 1
	end
end
Stub.equal(locks, 1, "locking again replaces the screen instead of stacking")
window:Unlock()
Stub.check(Stub.byName(window.body, "LockScreen") == nil, "Unlock removes it")

-- Dialog buttons held back by a countdown.
local deleted = false
window:Dialog({ Title = "Delete save?", Buttons = { { Title = "Keep" }, { Title = "Delete", Variant = "Danger", Delay = 3, Callback = function()
	deleted = true
end } } })
local delete = Stub.find(overlayFind("Dialog"), function(instance)
	return instance.Name == "Button" and string.find(instance.Text, "Delete", 1, true) ~= nil
end)
Stub.check(string.find(delete.Text, "(3)", 1, true) ~= nil, "a delayed button counts down")
Stub.click(delete)
Stub.flush()
Stub.check(not deleted and overlayFind("Dialog") ~= nil, "it ignores presses until the count ends")
Stub.advance(3.5)
Stub.click(delete)
Stub.flush()
Stub.check(deleted, "then it works")

window:Unload()
local again = Halcyon:CreateWindow({ Title = "Panel Hub", Folder = "PanelHub", Version = "2.1" })
Stub.check(again:Changelog({ Entries = { "Again" } }) == nil, "the seen version is remembered across runs")
again:Unload()
