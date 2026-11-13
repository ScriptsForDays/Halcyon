-- Window looks, open animations, tab indicators, page headers, notices,
-- tabs inside sections, header switches, ShowWhen and SetEnabled.
local Internal = Halcyon.Internal
local Styles = Internal.Styles

for _, kind in { "Window", "Open", "PageTransition", "Controls", "TabIndicator" } do
	Stub.check(#Halcyon:GetStyles(kind) > 1, kind .. " has looks to choose from")
end

-- Window looks and transparency.
local glass = Halcyon:CreateWindow({ Title = "Glass Hub", Folder = "GlassHub", WindowStyle = "Glass" })
Stub.equal(glass.root.BackgroundTransparency, 0.14, "glass lets the game show through")
Stub.check(Stub.byName(glass.root, "Sheen") ~= nil, "glass has a sheen across the top")
Stub.equal(glass:SetTransparency(0.9), 0.6, "transparency never goes past 0.6")
glass:Unload()
local gradient = Halcyon:CreateWindow({ Title = "Gradient Hub", Folder = "GradientHub", WindowStyle = "Gradient" })
Stub.check(gradient.root:FindFirstChildOfClass("UIGradient") ~= nil, "a gradient window has a gradient")
gradient:Unload()
local pictured = Halcyon:CreateWindow({ Title = "Image Hub", Folder = "ImageHub", BackgroundImage = "rbxassetid://1", BackgroundImageTransparency = 0.6 })
local backdrop = Stub.byName(pictured.root, "Backdrop")
Stub.check(backdrop ~= nil and backdrop.ImageTransparency == 0.6, "BackgroundImage fills the window at the strength asked")
pictured:Unload()

-- Open animations: the default hides at once; a chosen look animates out.
local plain = Halcyon:CreateWindow({ Title = "Plain Hub", Folder = "PlainShell" })
plain:Hide()
Stub.check(not plain.root.Visible, "the default look hides at once")
plain:Show()
Stub.advance(1)
Stub.equal(plain.uiScale.Scale, 1, "and pops back to full size")
plain:Unload()
local rising = Halcyon:CreateWindow({ Title = "Rise Hub", Folder = "RiseHub", OpenAnimation = "Rise" })
local rest = rising.root.Position
rising:Hide()
Stub.check(rising.root.Visible, "a chosen open look plays before hiding")
Stub.advance(0.5)
Stub.check(not rising.root.Visible, "and then hides")
rising:Show()
Stub.advance(1)
Stub.equal(rising.root.Position, rest, "it rises back to where it was")
rising:Hide()
rising:Show()
Stub.advance(1)
Stub.check(rising.root.Visible, "showing again during the exit cancels the hide")
rising:Unload()

-- A new window waits in its starting pose until a frame has been drawn, so a
-- long first layout doesn't swallow the motion; scaling would make the text
-- look like it grows.
local RunService = game:GetService("RunService")
local fresh = Halcyon:CreateWindow({ Title = "Fresh Hub", Folder = "FreshHub" })
local settled = fresh.root.Position
Stub.flush()
Stub.equal(fresh.root.Position, settled + UDim2.fromOffset(0, 14), "a new window starts a little below its place")
Stub.equal(fresh.uiScale.Scale, 1, "at full size")
RunService.RenderStepped:Fire(1 / 60)
RunService.Heartbeat:Fire(1 / 60)
Stub.advance(1)
Stub.equal(fresh.root.Position, settled, "then rises into place after the first frame")
fresh:Unload()

-- Mac controls, top bar buttons, sidebar toggle and width.
local pressed = 0
local mac = Halcyon:CreateWindow({ Title = "Mac Hub", Folder = "MacHub", TopbarControls = "Mac", SidebarToggle = true, SidebarWidth = 230 })
local dots = Stub.byName(mac.root, "Dots")
Stub.check(dots ~= nil, "the Mac look puts dots in the top bar")
local extra = mac:AddTopbarButton({ Icon = "bell", Callback = function()
	pressed += 1
end })
Stub.click(Stub.byName(mac.topbarActions, "bell"))
Stub.flush()
Stub.equal(pressed, 1, "a top bar button runs its callback")
extra:Destroy()
Stub.check(Stub.byName(mac.topbarActions, "bell") == nil, "and can be removed")
mac:Tab({ Title = "Movement" })
Stub.equal(mac:lane("Sidebar"), 230, "SidebarWidth sets the sidebar's width")
Stub.click(Stub.byName(mac.topbarActions, "panel-left"))
Stub.equal(mac.tabStyle, "Rail", "the sidebar toggle folds to the rail")
Stub.click(Stub.byName(dots, "maximize-2"))
Stub.equal(mac.size, Vector2.new(1100, 700), "the third dot makes the window large")
Stub.click(Stub.byName(dots, "maximize-2"))
Stub.check(mac.size ~= Vector2.new(1100, 700), "and puts it back")
Stub.click(Stub.byName(dots, "x"))
Stub.check(not mac.Visible, "the red dot hides the window")
mac:Unload()

-- Snapping.
local snapping = Halcyon:CreateWindow({ Title = "Snap Hub", Folder = "SnapHub", Snap = true, SavePreferences = false })
Stub.equal(snapping:snap(Vector2.new(14, 12)), Vector2.new(8, 8), "a window dropped near the corner lines up with the edges")
Stub.equal(snapping:snap(Vector2.new(300, 300)), Vector2.new(300, 300), "one dropped in open space stays where it is")
snapping:Unload()

-- Tab indicators, page headers, notices and tab-name search.
local hub = Halcyon:CreateWindow({ Title = "Shell Hub", Folder = "ShellHub", TabIndicator = "Pill", PageTransition = "None" })
local farm = hub:Tab({ Title = "Farming", Icon = "leaf", Description = "Collects resources for you." })
Stub.check(Stub.byText(farm.page, "Collects resources for you.") ~= nil, "a tab Description heads its page")
Stub.equal(farm.look, Styles.get("TabIndicator", "Pill"), "the window's indicator look reaches its tabs")
local notice = farm:Notice({ Title = "Patched", Content = "Auto sell is down.", Kind = "warning", Dismissible = true })
Stub.check(farm.notices.Visible, "a notice shows at the top of the page")
Stub.click(Stub.byName(farm.notices, "Dismiss"))
Stub.check(not farm.notices.Visible, "a dismissed notice leaves no empty space")
notice = farm:Notice("Plain text works too")
notice:Destroy()
for _, look in Halcyon:GetStyles("TabIndicator") do
	hub.styles.TabIndicator = look
	for _, style in { "Sidebar", "Rail", "Top", "Dock" } do
		hub:SetTabStyle(style)
		Stub.check(farm.button ~= nil, "indicator " .. look .. " builds on " .. style)
	end
end
hub:SetTabStyle("Sidebar")

local section = farm:Section({ Title = "Fields" })
local harvest = section:Toggle({ Title = "Harvest wheat" })
local combat = hub:Tab({ Title = "Combat" })
combat:Section({ Title = "Aim" }):Toggle({ Title = "Lock on" })
hub:Search("combat")
Stub.check(hub.selected == combat, "searching a tab's name finds the tab")
hub:Search("wheat")
Stub.check(string.find(Stub.byName(harvest.Frame, "Title").Text, "<font", 1, true) ~= nil, "the match is marked in the title")
hub:Search("")
Stub.equal(Stub.byName(harvest.Frame, "Title").Text, "Harvest wheat", "the mark clears with the search")

local box = farm:Section({ Title = "Targets", Tabs = { "Crops", "Animals" } })
local crops = box:Toggle({ Title = "Carrots" })
local cows = box:Tab("Animals"):Toggle({ Title = "Cows" })
Stub.check(crops.Frame:IsDescendantOf(box.pages.Crops.frame), "elements on the section go to its first inner tab")
Stub.check(not box.pages.Animals.frame.Visible, "other inner tabs start hidden")
box:SelectTab("Animals")
Stub.check(box.pages.Animals.frame.Visible and not box.pages.Crops.frame.Visible, "picking an inner tab shows only its rows")
hub:Search("carrots")
Stub.check(box.pages.Crops.frame.Visible, "a search shows matches in every inner tab")
hub:Search("")
Stub.check(cows.Frame ~= nil, "inner tabs hold elements")
local ok = pcall(function()
	box:Tab("Missing")
end)
Stub.check(not ok, "asking for an inner tab that does not exist is an error")

-- Header switch and SetEnabled.
local switched = farm:Section({ Title = "Auto", Switch = { Default = true, Flag = "AutoSection" } })
local seller = switched:Toggle({ Title = "Auto sell" })
switched.switch:Set(false)
Stub.check(seller:IsLocked(), "turning a section's switch off greys its rows")
local late = switched:Toggle({ Title = "Auto buy" })
Stub.check(late:IsLocked(), "a row added while the switch is off starts greyed")
switched.switch:Set(true)
Stub.check(not seller:IsLocked() and not late:IsLocked(), "turning it on frees them again")
Stub.check(hub.Flags.AutoSection ~= nil, "the switch saves with configs under its Flag")
seller:SetDisabled(true)
hub:SetEnabled(false)
Stub.check(harvest:IsLocked(), "SetEnabled(false) greys every row")
hub:SetEnabled(true)
Stub.check(not harvest:IsLocked(), "SetEnabled(true) frees them")
Stub.check(seller:IsLocked(), "but a row the hub disabled stays disabled")

-- ShowWhen.
local mode = section:Dropdown({ Title = "Mode", Values = { "Safe", "Fast" }, Flag = "FarmMode" })
local speed = section:Slider({ Title = "Speed", Min = 1, Max = 5 })
speed:ShowWhen("FarmMode", "Fast")
Stub.check(speed.Hidden, "a row hides while its condition is false")
mode:Set("Fast")
Stub.check(not speed.Hidden, "and shows once it holds")
local extras = farm:Section({ Title = "Extras" })
extras:ShowWhen(harvest)
Stub.check(extras.Hidden, "a section can follow a toggle")
harvest:Set(true)
Stub.check(not extras.Hidden, "and shows when it switches on")
local bad = pcall(function()
	speed:ShowWhen("NoSuchFlag", true)
end)
Stub.check(not bad, "following a Flag that does not exist is an error")

-- MaxHeight.
local tall = farm:Section({ Title = "Log", MaxHeight = 120 })
Stub.equal(tall.rows.ClassName, "ScrollingFrame", "MaxHeight makes the rows scroll")
hub:Unload()
