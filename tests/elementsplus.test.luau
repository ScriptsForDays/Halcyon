-- The newer elements: a model preview, rings, charts, an inventory grid
-- and saved places.

local window = Halcyon:CreateWindow({ Title = "Elements", Folder = "ElementsPlus", SavePreferences = false })
local tab = window:Tab({ Title = "Pets" })
local section = tab:Section({ Title = "Main" })
Stub.flush()

-- Viewport copies the model and leaves the original alone.
local pet = Instance.new("Model")
pet.Name = "Dragon"
local body = Instance.new("Part")
body.Parent = pet
local preview = section:Viewport({ Title = "Preview", Model = pet, Height = 160 })
Stub.flush()
local frame = Stub.byName(preview.Frame, "Preview")
Stub.check(frame ~= nil and frame.ClassName == "ViewportFrame", "a ViewportFrame shows the model")
Stub.check(Stub.byName(frame, "Dragon") ~= nil and pet.Parent == nil, "it holds a copy, not the original")
Stub.equal(preview:Get(), pet, "Get returns the model it shows")
local other = Instance.new("Model")
other.Name = "Phoenix"
preview:Set(other)
Stub.check(Stub.byName(frame, "Phoenix") ~= nil and Stub.byName(frame, "Dragon") == nil, "Set swaps the model")

-- Gauge.
local health = section:Gauge({ Title = "Health", Value = 80, Max = 100, Suffix = "%", Thresholds = { { At = 0.25, Role = "danger" } } })
Stub.flush()
Stub.equal(Stub.byName(health.Frame, "Value").Text, "80%", "the gauge shows its value")
health:Set(10)
Stub.advance(0.5)
Stub.equal(health:Get(), 10, "Set changes it")
Stub.check(Stub.byName(health.Frame, "Value").Text == "10%", "and the label")

-- Knob snaps to its step and calls back.
local turned = {}
local volume = section:Knob({ Title = "Volume", Min = 0, Max = 10, Step = 2, Default = 4, Flag = "Volume", Callback = function(value)
	table.insert(turned, value)
end })
Stub.flush()
Stub.equal(volume:Get(), 4, "the knob starts at its default")
Stub.equal(#turned, 0, "making it runs nothing")
volume:Set(7.1)
Stub.equal(volume:Get(), 8, "values snap to the step")
Stub.equal(turned[1], 8, "Set calls back")

-- Charts.
local loot = section:Chart({ Title = "Loot", Type = "Donut", Items = { { Name = "Coins", Value = 30 }, { Name = "Gems", Value = 10 } } })
Stub.flush()
Stub.equal(Stub.byName(loot.Frame, "Centre").Text, "40", "a donut shows the total in the middle")
Stub.check(Stub.find(loot.Frame, function(instance)
	return instance.Name == "Name" and string.find(instance.Text, "75%", 1, true) ~= nil
end) ~= nil, "the legend gives each share")
loot:Set({ { Name = "Coins", Value = 5 } })
Stub.equal(Stub.byName(loot.Frame, "Centre").Text, "5", "Set replaces the items")
local rate = section:Chart({ Title = "Per hour", Type = "Line", Labels = { "1", "2", "3" }, Series = { { Name = "Coins", Values = { 1, 4, 2 } }, { Name = "Gems", Values = { 0, 1, 3 } } } })
Stub.flush()
Stub.check(#rate:Get() == 2, "a line chart keeps its series")
rate:Push({ 5, 6 }, "4", 3)
Stub.equal(#rate:Get()[1].Values, 3, "Push keeps the newest values")

-- ItemGrid.
local picks = {}
local eggs = section:ItemGrid({
	Title = "Eggs",
	Sort = "Rarity",
	Items = {
		{ Title = "Basic egg", Rarity = "Common", Count = 12, Value = "basic" },
		{ Title = "Golden egg", Rarity = "Legendary", Count = 1, Value = "golden" },
		{ Title = "Shadow egg", Rarity = "Epic", Value = "shadow", Disabled = true },
	},
	Callback = function(value)
		table.insert(picks, value)
	end,
})
Stub.flush()
local cards = {}
for _, instance in Stub.byName(eggs.Frame, "Items"):GetChildren() do
	if instance.Name == "Item" then
		cards[instance.LayoutOrder] = instance
	end
end
Stub.equal(Stub.byName(cards[1], "Name").Text, "Golden egg", "sorted rarest first")
Stub.equal(Stub.byName(cards[3], "Count").Text, "x12", "counts show on the card")
Stub.equal(Stub.byName(cards[1], "RarityName").Text, "Legendary", "the rarity is written, not only coloured")
Stub.click(cards[1])
Stub.equal(eggs:Get(), "golden", "a press picks the item")
Stub.equal(picks[1], "golden", "and calls back")
Stub.click(cards[2])
Stub.equal(eggs:Get(), "golden", "a disabled item can't be picked")
eggs:SetCount("basic", 13)
Stub.equal(Stub.byName(cards[3], "Count").Text, "x13", "SetCount updates one card")

-- Waypoints.
local moved = {}
local places = section:Waypoints({ Title = "Places", Flag = "Places", Teleport = function(cframe, name)
	table.insert(moved, name)
end, GetPosition = function()
	return CFrame.new(10, 5, 2)
end })
Stub.flush()
local nameBox = Stub.byName(places.Frame, "PlaceName")
nameBox.Text = "Shop"
Stub.click(Stub.byName(places.Frame, "SaveHere"))
Stub.click(Stub.byName(places.Frame, "SaveHere"))
local list = places:Get()
Stub.equal(#list, 2, "Save here adds the current position")
Stub.equal(list[1].Name, "Shop", "with the typed name")
Stub.equal(list[2].Name, "Place 2", "or a numbered one")
Stub.check(places:Teleport("Shop") and moved[1] == "Shop", "Teleport goes through the hub's function")
Stub.check(window:SaveConfig("places"), "saved")
places:Set({})
Stub.check(window:LoadConfig("places"), "loaded")
list = places:Get()
Stub.check(#list == 2 and list[1].CFrame.Position.X == 10, "places come back from a config")
window:Unload()
