-- The 2.2 components: MenuButton and row menus, Link, Banner, Stat and
-- Stats, Graph, Log, Tags, List, PlayerList, Group, Sheet and QuickBar.
local Internal = Halcyon.Internal
local Theme, library = Internal.Theme, Internal.library
local Players = game:GetService("Players")

local hub = Halcyon:CreateWindow({ Title = "Parts Hub", Folder = "PartsHub", SavePreferences = false })
local tab = hub:Tab({ Title = "Farm" })
local section = tab:Section({ Title = "Tools" })

-- MenuButton.
local renamed = false
local menu = section:MenuButton({
	Title = "Config",
	Items = {
		{ Title = "Rename", Icon = "pencil", Callback = function()
			renamed = true
		end },
		{ Divider = true },
		{ Title = "Delete", Icon = "trash-2", Danger = true },
	},
})
Stub.click(Stub.byName(menu.Frame, "Menu"))
Stub.check(library.popup ~= nil and Stub.byText(library.popup.frame, "Rename") ~= nil, "a MenuButton opens its items")
Stub.check(Stub.byName(library.popup.frame, "Divider") ~= nil, "with dividers between groups")
Stub.click(Stub.byText(library.popup.frame, "Rename"))
Stub.flush()
Stub.check(renamed and library.popup == nil, "an item runs its callback and closes the menu")

-- A row's own menu, on right-click.
local reset = false
local speed = section:Slider({ Title = "Speed", Min = 1, Max = 10, Default = 5, Menu = { { Title = "Reset", Callback = function()
	reset = true
end } } })
speed.Frame.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton2, Position = Vector3.new(10, 10, 0) })
Stub.check(library.popup ~= nil and Stub.byText(library.popup.frame, "Reset") ~= nil, "Menu opens on a right-click on the row")
Stub.click(Stub.byText(library.popup.frame, "Reset"))
Stub.flush()
Stub.check(reset, "and its item runs")

-- Link.
Stub.genv.setclipboard = function(text)
	Stub.clipboard = text
end
local link = section:Link({ Title = "Discord", Url = "https://discord.gg/example" })
Stub.check(Stub.byText(link.Frame, "discord.gg") ~= nil, "a Link shows its site under the title")
Stub.click(link.Frame)
Stub.flush()
Stub.equal(Stub.clipboard, "https://discord.gg/example", "pressing a Link copies its address")
local source = section:Link({ Title = "Source", Url = "https://github.com/example", Icon = "code" })
local mark = Stub.byName(source.Frame, "Mark")
Stub.equal(mark:FindFirstChildWhichIsA("ImageLabel"):GetAttribute("HalcyonIcon"), "copy", "a Link's own Icon leads the row; its button keeps the copy icon")

-- Banner.
local opened = false
local banner = section:Banner({ Title = "Season 4 is live", Text = "New map, new bosses.", Button = { Title = "See what's new", Callback = function()
	opened = true
end } })
Stub.check(Stub.byText(banner.Frame, "Season 4 is live") ~= nil, "a Banner shows its title")
Stub.click(Stub.byText(banner.Frame, "See what's new"))
Stub.flush()
Stub.check(opened, "and its button runs")

-- Stat and Stats.
local coins = section:Stat({ Title = "Coins", Value = "1,240", Unit = "per hour", Change = "+12%" })
Stub.check(Stub.byText(coins.Frame, "1,240") ~= nil, "a Stat shows its value")
Stub.equal(Stub.byName(coins.Frame, "Change").TextColor3, Theme.color("success"), "a rising change is green")
coins:Set("1,300")
Stub.check(Stub.byText(coins.Frame, "1,300") ~= nil, "Set changes the value")
coins:SetChange("-3%")
Stub.equal(Stub.byName(coins.Frame, "Change").TextColor3, Theme.color("danger"), "a falling change is red")
local stats = section:Stats({ Items = { { Title = "FPS", Value = 60 }, { Title = "Ping", Value = 40, Unit = "ms" }, { Title = "Players", Value = 12, Key = "players" } } })
stats:Set("players", 13)
Stub.equal(stats:Get("players"), 13, "Stats reaches each figure by its Key")
Stub.check(Stub.byText(stats.Frame, "13") ~= nil, "and shows the new value")

-- Graph.
local graph = section:Graph({ Title = "Frame rate", Max = 5, Suffix = " fps", Values = { 58, 60 } })
for value = 1, 6 do
	graph:Push(50 + value)
end
Stub.equal(#graph:Get(), 5, "a Graph keeps only its last Max values")
Stub.check(Stub.byText(graph.Frame, "56 fps") ~= nil, "and shows the newest beside its title")
graph:Clear()
Stub.equal(#graph:Get(), 0, "Clear empties it")

-- Log.
local log = section:Log({ Title = "Output", Timestamps = false })
log:Info("Bought 3 seeds")
log:Error("Shop closed")
Stub.check(Stub.byText(log.Frame, "Bought 3 seeds") ~= nil, "a Log shows its lines")
Stub.click(Stub.byText(log.Frame, "Error"))
Stub.check(not Stub.byText(log.Frame, "Bought 3 seeds").Visible and Stub.byText(log.Frame, "Shop closed").Visible, "the Error filter hides other lines")
Stub.equal(Stub.byName(log.Frame, "Error").BackgroundTransparency, 0, "the picked filter chip is filled, so its text shows")
Stub.equal(log:Get(), "Bought 3 seeds\nShop closed", "Get returns every line as text")
log:Clear()
Stub.equal(log:Get(), "", "Clear empties it")

-- Tags.
local whitelist = section:Tags({ Title = "Whitelist", Default = { "Ana" }, Max = 3, Flag = "Whitelist", Suggestions = { "Bram", "Bea" } })
local entry = Stub.byName(whitelist.Frame, "Entry")
entry.Text = "Kofi"
entry.FocusLost:Fire(true)
Stub.equal(table.concat(whitelist:Get(), ","), "Ana,Kofi", "Enter adds what was typed")
entry.Text = "ana"
entry.FocusLost:Fire(true)
Stub.equal(#whitelist:Get(), 2, "the same word twice is refused")
entry.Text = "B"
Stub.check(Stub.byText(whitelist.Frame, "Bram") ~= nil, "matching suggestions show while typing")
Stub.click(Stub.byText(whitelist.Frame, "Bram"))
Stub.equal(#whitelist:Get(), 3, "and pressing one adds it")
Stub.check(not entry.Visible, "at Max the entry box goes")
Stub.click(Stub.byName(Stub.byText(whitelist.Frame, "Ana").Parent, "Remove"))
Stub.equal(table.concat(whitelist:Get(), ","), "Kofi,Bram", "the × removes a tag")
Stub.check(hub.Flags.Whitelist == whitelist, "Tags saves with configs under its Flag")

-- List.
local route = section:List({ Title = "Route", Values = { "Forest", "Mines", "Docks" }, Default = "Mines" })
Stub.equal(route:Get(), "Mines", "a List starts on its Default")
Stub.click(Stub.byText(route.Frame, "Docks"))
Stub.equal(route:Get(), "Docks", "pressing an item picks it")
local picks = section:List({ Title = "Ores", Values = { "Iron", "Gold", "Ruby" }, Multi = true })
Stub.click(Stub.byText(picks.Frame, "Gold"))
Stub.click(Stub.byText(picks.Frame, "Iron"))
Stub.equal(table.concat(picks:Get(), ","), "Iron,Gold", "Multi keeps several, in list order")
local order = section:List({ Title = "Priority", Values = { "Boss", "Chest", "Mob" }, Reorder = true })
Stub.equal(table.concat(order:Get(), ","), "Boss,Chest,Mob", "Reorder returns every value in order")
order:Set({ "Mob", "Boss" })
Stub.equal(table.concat(order:Get(), ","), "Mob,Boss,Chest", "Set puts the given values first")
local filtered = section:List({ Title = "Zones", Values = { "North", "South" }, Search = true })
Stub.byName(filtered.Frame, "Search").Text = "nor"
Stub.check(Stub.byText(filtered.Frame, "North").Parent.Visible and not Stub.byText(filtered.Frame, "South").Parent.Visible, "Search filters the items")

-- PlayerList.
local watched
local guest = Instance.new("Player")
guest.Name = "builder_ana"
guest.DisplayName = "Ana"
guest.UserId = 2
guest.Parent = Players
local people = section:PlayerList({ Title = "Players", Selectable = true, Actions = { { Title = "Spectate", Icon = "eye", Callback = function(player)
	watched = player
end } } })
Stub.check(Stub.byText(people.Frame, "@builder_ana") ~= nil, "a PlayerList shows the server's players")
Stub.check(Stub.byText(people.Frame, "@TestUser") == nil, "but not the local player unless asked")
Stub.click(Stub.byName(Stub.byName(people.Frame, "builder_ana"), "Spectate"))
Stub.flush()
Stub.equal(watched, guest, "an action gets the player it was pressed for")
Stub.click(Stub.byName(people.Frame, "builder_ana"))
Stub.equal(people:Get(), "builder_ana", "Selectable picks the pressed player")
local second = Instance.new("Player")
second.Name = "late_kofi"
second.DisplayName = "Kofi"
second.UserId = 3
second.Parent = Players
Players.PlayerAdded:Fire(second)
Stub.check(Stub.byText(people.Frame, "@late_kofi") ~= nil, "a player who joins gets a row")
Players.PlayerRemoving:Fire(second)
Stub.check(Stub.byText(people.Frame, "@late_kofi") == nil, "and loses it on leaving")

-- Group.
local pair = section:Group({ Columns = 2 })
local left = pair:Toggle({ Title = "Auto farm" })
local right = pair:Toggle({ Title = "Auto sell" })
Stub.place(pair.Frame, 0, 0, 600, 40)
pair.Frame:GetPropertyChangedSignal("AbsoluteSize"):Fire()
Stub.flush()
Stub.equal(left.Frame.Size.X.Scale, 0.5, "a Group gives each control half the line")
Stub.equal(right.Frame.Parent, pair.Frame, "and holds them side by side")

-- Sheet.
local sheet = hub:Sheet({ Title = "Auto farm options" })
local radius = sheet:Slider({ Title = "Radius", Min = 10, Max = 200, Flag = "FarmRadius" })
Stub.check(radius ~= nil and hub.Flags.FarmRadius == radius, "a Sheet takes controls like a section")
sheet:Open()
Stub.check(sheet.IsOpen and sheet.layer.Visible, "Open slides it in")
Stub.click(sheet.scrim)
Stub.advance(1)
Stub.check(not sheet.IsOpen and not sheet.layer.Visible, "a press on the page behind closes it")

-- QuickBar.
local farming = section:Toggle({ Title = "Auto farm", Flag = "QuickFarm" })
local panicked = false
local bar = hub:QuickBar({ Items = { "QuickFarm", { Title = "Stop all", Icon = "octagon-x", Callback = function()
	panicked = true
end } } })
Stub.click(Stub.byName(bar.Frame, "Auto farm"))
Stub.check(farming:Get() == true, "a QuickBar item flips its toggle")
Stub.click(Stub.byName(bar.Frame, "Stop all"))
Stub.flush()
Stub.check(panicked, "and a button item runs its callback")
hub:Hide()
Stub.check(bar.Frame.Visible, "the bar stays when the window hides")
hub:Unload()
