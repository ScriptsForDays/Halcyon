-- On/off switches: the window's own pieces given to CreateWindow and turned
-- with Window:Set, and Visible / Enabled / ShowWhen / EnableWhen on rows,
-- sections and tabs.
local Lighting = game:GetService("Lighting")

-- Window switches given when the window is made.
local hub = Halcyon:CreateWindow({
	Title = "Switch Hub",
	Folder = "SwitchHub",
	SavePreferences = false,
	Search = false,
	Minimize = false,
	Close = false,
	Resize = false,
	Drag = false,
	Shadow = false,
	Tooltips = false,
	Blur = true,
	Watermark = true,
	KeybindList = { Title = "Binds" },
	SettingsTab = true,
})
Stub.check(not hub.searchFrame.Visible, "Search = false hides the search box")
Stub.check(not hub.minimizeButton.Visible, "Minimize = false hides the minimise button")
Stub.check(not hub.closeButton.Visible, "Close = false hides the close button")
Stub.check(hub.grip == nil, "Resize = false leaves out the resize grip")
Stub.check(hub.shadow == nil, "Shadow = false leaves out the shadow")
Stub.equal(hub:Get("Drag"), false, "Drag = false locks the window in place")
Stub.equal(hub:Get("Tooltips"), false, "Tooltips = false turns hover tips off")
Stub.check(hub.blur ~= nil and hub.blur.Parent == Lighting, "Blur = true blurs the game behind the window")
Stub.check(hub.watermark ~= nil and Stub.byName(hub.gui, "Watermark") ~= nil, "Watermark = true shows the watermark")
Stub.check(hub.keybindList ~= nil and Stub.byText(hub.gui, "Binds") ~= nil, "KeybindList takes a table of settings")
local farm = hub:Tab({ Title = "Farm" })
Stub.flush()
Stub.check(hub.settingsTab ~= nil, "SettingsTab = true adds the settings tab")
Stub.check(hub.tabs[#hub.tabs] == hub.settingsTab, "after the hub's own tabs")

-- The same switches while the hub runs.
Stub.check(hub:Set("Search", true) and hub.searchFrame.Visible, "Set brings the search box back")
hub:Set("Close", true)
Stub.check(hub.closeButton.Visible and hub:Get("Close"), "and the close button")
hub:Set("Minimize", true)
Stub.check(hub.minimizeButton.Visible and hub:Get("Minimizable"), "the plain name works with Set too")
hub:Set("Resize", true)
Stub.check(hub.grip ~= nil and hub.grip.Visible, "the grip can be turned on later")
hub:Set("Shadow", true)
Stub.check(hub.shadow ~= nil and hub:Get("Shadow"), "and the shadow")
hub:Set("Watermark", false)
Stub.check(hub.watermark == nil and Stub.byName(hub.gui, "Watermark") == nil, "Set(\"Watermark\", false) removes the watermark")
hub:Set("Blur", false)
Stub.advance(1)
Stub.equal(hub.blur.Size, 0, "turning Blur off fades it away")
hub:Set("CommandPalette", true)
Stub.check(hub:Get("CommandPalette"), "the command palette can be switched on later")
hub:Set("Drag", true)
Stub.equal(hub:Get("Drag"), true, "and dragging unlocked")
hub:Set("SettingsTab", false)
Stub.check(hub.settingsTab.Hidden and hub.settingsTab.button == nil, "the settings tab hides")
hub:Set("Profile", false)
Stub.equal(hub:Get("Profile"), false, "the profile card switches off")
Stub.check(not hub:Set("NoSuchSwitch", true), "an unknown switch is refused")
Stub.equal(hub:Get("NoSuchSwitch"), nil, "and has no state")

-- Rows.
local section = farm:Section({ Title = "Auto" })
local hidden = section:Toggle({ Title = "Hidden", Visible = false })
Stub.check(hidden.Hidden and not hidden.Frame.Visible, "Visible = false makes a row hidden")
local off = section:Toggle({ Title = "Off", Enabled = false })
Stub.check(off:IsLocked(), "Enabled = false greys a row")
off:SetEnabled(true)
Stub.check(not off:IsLocked(), "SetEnabled(true) frees it")
local alsoOff = section:Button({ Title = "Old name", Disabled = true })
Stub.check(alsoOff:IsLocked(), "Disabled = true works too")
local master = section:Toggle({ Title = "Master", Flag = "Master" })
local child = section:Slider({ Title = "Speed", Min = 1, Max = 10, ShowWhen = "Master" })
Stub.check(child.Hidden, "ShowWhen given when a row is made hides it until the toggle is on")
master:Set(true)
Stub.check(not child.Hidden, "and shows it once it is")
local go = section:Button({ Title = "Go", EnableWhen = { "Mode", "Fast" } })
local mode = section:Dropdown({ Title = "Mode", Values = { "Safe", "Fast" }, Default = "Safe", Flag = "Mode" })
Stub.flush()
Stub.check(go:IsLocked(), "EnableWhen can name a control made after it")
mode:Set("Fast")
Stub.check(not go:IsLocked(), "and frees the row when the value matches")
local keyed = section:Toggle({ Title = "Keyed", ShowWhen = { Flag = "Mode", Value = "Safe" } })
Stub.check(keyed.Hidden, "ShowWhen also takes { Flag, Value }")

-- Sections.
local quiet = farm:Section({ Title = "Quiet", Visible = false })
Stub.check(quiet.Hidden and not quiet.root.Visible, "Visible = false hides a section")
local greyed = farm:Section({ Title = "Greyed", Enabled = false })
local inside = greyed:Toggle({ Title = "Inside" })
Stub.check(inside:IsLocked(), "a row in a section made with Enabled = false starts greyed")
greyed:SetEnabled(true)
Stub.check(not inside:IsLocked(), "SetEnabled(true) on the section frees its rows")
local follows = farm:Section({ Title = "Follows", EnableWhen = "Master" })
local follower = follows:Toggle({ Title = "Follower" })
master:Set(false)
Stub.check(follower:IsLocked(), "a section's EnableWhen greys its rows while the condition is false")
master:Set(true)
Stub.check(not follower:IsLocked(), "and frees them when it holds")

-- Tabs.
local secret = hub:Tab({ Title = "Secret", Visible = false })
Stub.check(secret.Hidden and secret.button == nil, "Visible = false keeps a tab out of the navigation")
hub:SelectTab(secret)
Stub.check(hub.selected ~= secret, "a hidden tab can't be opened")
secret:SetVisible(true)
Stub.check(secret.button ~= nil, "SetVisible(true) puts it back")
hub:SelectTab(secret)
secret:SetVisible(false)
Stub.check(hub.selected ~= secret and hub.selected ~= nil, "hiding the open tab opens another")
local extra = hub:Tab({ Title = "Boss rush", ShowWhen = "Master" })
Stub.check(not extra.Hidden, "a tab can follow a toggle")
master:Set(false)
Stub.check(extra.Hidden, "and hides while it is off")
hub:Search("Secret")
Stub.check(hub.selected ~= secret, "search never opens a hidden tab")
hub:Search("")

-- Hiding the window fades the blur; unloading removes it.
hub:Set("Blur", 20)
hub:Hide()
Stub.advance(1)
Stub.equal(hub.blur.Size, 0, "the blur fades while the window is hidden")
hub:Show()
Stub.advance(1)
Stub.equal(hub.blur.Size, 20, "and comes back at the size asked")
local blur = hub.blur
hub:Unload()
Stub.check(blur.Parent == nil, "unloading removes the blur")

-- The older names still work, and the hub's options table is left alone.
local options = { Title = "Plain Names", Folder = "PlainNames", SavePreferences = false, Minimize = false }
local plain = Halcyon:CreateWindow(options)
Stub.check(not plain.minimizeButton.Visible, "Minimize = false on its own")
Stub.equal(options.Minimizable, nil, "the hub's own options table is left as it was")
plain:Unload()
local legacy = Halcyon:CreateWindow({ Title = "Legacy", Folder = "LegacyHub", SavePreferences = false, Minimizable = false, Resizable = false })
Stub.check(not legacy.minimizeButton.Visible and legacy.grip == nil, "Minimizable and Resizable still work")
legacy:Unload()

-- The public list of switch names.
local names = Halcyon:GetSwitches()
Stub.check(table.find(names, "Search") ~= nil and table.find(names, "NotificationCenter") ~= nil, "GetSwitches lists the window's switches")
Stub.check(table.find(names, "Minimize") ~= nil and table.find(names, "Minimizable") ~= nil, "both the plain name and the old one are listed")
