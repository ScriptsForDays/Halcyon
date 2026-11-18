-- Favourites mirror starred rows in a tab of their own, both ways, and are
-- remembered; TabReorder lets the player pin and move tabs.

local function menuItem(handle, title)
	handle.Frame.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton2, Position = Vector3.zero }, false)
	Stub.flush()
	return Stub.find(game:GetService("Players").LocalPlayer.PlayerGui, function(instance)
		return instance.Text == title
	end)
end

local window = Halcyon:CreateWindow({ Title = "Stars", Folder = "StarHub", Favourites = true, TabReorder = true })
local farm = window:Tab({ Title = "Farm" })
local calls = {}
local auto = farm:Toggle({ Title = "Auto farm", Flag = "AutoFarm", Callback = function(on)
	table.insert(calls, on)
end })
local speed = farm:Slider({ Title = "Speed", Flag = "Speed", Min = 0, Max = 100, Default = 20 })
local combat = window:Tab({ Title = "Combat" })
local misc = window:Tab({ Title = "World" })
Stub.flush()

local favourites = window.favourites.tab
Stub.check(favourites.Hidden, "the Favourites tab hides while nothing is starred")
local add = menuItem(auto, "Add to favourites")
Stub.check(add ~= nil, "a row's menu offers Add to favourites")
Stub.click(add)
Stub.flush()
Stub.check(not favourites.Hidden, "starring shows the Favourites tab")
local copy = window.favourites.copies["flag:AutoFarm"]
Stub.check(copy ~= nil and copy.isCopy, "the tab holds a copy of the row")
Stub.check(auto.favouriteMark.Visible, "the original shows a star")

-- Both ways, without a second flag.
copy:Set(true)
Stub.flush()
Stub.equal(auto:Get(), true, "changing the copy changes the original")
Stub.equal(calls[#calls], true, "and runs the original's callback")
auto:Set(false)
Stub.flush()
Stub.equal(copy:Get(), false, "changing the original updates the copy")
Stub.equal(window.Flags.AutoFarm, auto, "only the original holds the flag")
local values = window:GetValues()
Stub.equal(values.AutoFarm, false, "configs see one value")

-- Remembered across runs.
Stub.click(menuItem(speed, "Add to favourites"))
Stub.advance(1)
window:Unload()
local again = Halcyon:CreateWindow({ Title = "Stars", Folder = "StarHub", Favourites = true, TabReorder = true })
local farm2 = again:Tab({ Title = "Farm" })
farm2:Toggle({ Title = "Auto farm", Flag = "AutoFarm" })
farm2:Slider({ Title = "Speed", Flag = "Speed", Min = 0, Max = 100, Default = 20 })
again:Tab({ Title = "Combat" })
again:Tab({ Title = "World" })
Stub.flush()
Stub.check(again.favourites.copies["flag:AutoFarm"] ~= nil and again.favourites.copies["flag:Speed"] ~= nil, "starred rows come back on the next run")
Stub.check(not again.favourites.tab.Hidden, "with the tab showing")

-- Unstarring from the copy.
local copied = again.favourites.copies["flag:Speed"]
Stub.click(menuItem(copied, "Remove from favourites"))
Stub.flush()
Stub.equal(again.favourites.copies["flag:Speed"], nil, "the copy's menu can remove it")

-- Tab order: pin and move.
local function titles(win)
	local list = {}
	for _, tab in win:navOrder() do
		if not tab.Hidden then
			table.insert(list, tab.Title)
		end
	end
	return table.concat(list, ",")
end
local world = again.tabs[#again.tabs]
Stub.equal(titles(again), "Favourites,Farm,Combat,World", "tabs start in the order they were made")
local TabOrder = { move = nil }
world.button.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton2, Position = Vector3.zero }, false)
Stub.flush()
Stub.click(Stub.find(game:GetService("Players").LocalPlayer.PlayerGui, function(instance)
	return instance.Text == "Pin to top"
end))
Stub.flush()
Stub.equal(titles(again), "World,Favourites,Farm,Combat", "a pinned tab goes to the top")
local combatTab = again.tabs[3]
combatTab.button.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton2, Position = Vector3.zero }, false)
Stub.flush()
Stub.click(Stub.find(game:GetService("Players").LocalPlayer.PlayerGui, function(instance)
	return instance.Text == "Move up"
end))
Stub.flush()
Stub.equal(titles(again), "World,Favourites,Combat,Farm", "Move up swaps it with the tab above")
Stub.advance(1)
again:Unload()
local third = Halcyon:CreateWindow({ Title = "Stars", Folder = "StarHub", Favourites = true, TabReorder = true })
third:Tab({ Title = "Farm" })
third:Tab({ Title = "Combat" })
third:Tab({ Title = "World" })
Stub.flush()
Stub.equal(titles(third), "World,Combat,Farm", "the order is remembered")
third:Unload()
