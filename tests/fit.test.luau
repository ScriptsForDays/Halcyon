-- Longer words, as other languages have, stay inside their boxes: filter
-- chips and legends wrap, labels in fixed spots shrink before they are cut,
-- and a button's label is never wider than the button.

local window = Halcyon:CreateWindow({ Title = "Fit", Folder = "FitHub", SavePreferences = false })
local section = window:Tab({ Title = "Farm" }):Section({ Title = "Numbers and things" })
local log = section:Log({ Title = "Activity" })
local stat = section:Stat({ Title = "Memory", Value = 30, Unit = "MB" })
local donut = section:Chart({ Title = "Loot", Type = "Donut", Items = { { Name = "Coins", Value = 3 }, { Name = "Gems", Value = 1 } } })
local bars = section:Chart({ Title = "Per minute", Type = "Bars", Labels = { "1", "2" }, Series = { { Name = "Coins", Values = { 1, 2 } } } })
local eggs = section:ItemGrid({ Title = "Eggs", Items = { { Title = "Forest egg", Rarity = "Uncommon", Value = "forest" } } })
local open = section:Button({ Title = "Open the command palette", Style = "Filled" })
Stub.flush()

local levels = Stub.byName(log.Frame, "Levels")
Stub.check(levels.AutomaticSize == Enum.AutomaticSize.Y and levels:FindFirstChildOfClass("UIListLayout").Wraps, "log filters wrap onto a second line")

local function fits(label)
	local limit = label and label:FindFirstChildOfClass("UITextSizeConstraint")
	return label ~= nil and label.TextScaled and limit ~= nil and limit.MinTextSize < limit.MaxTextSize
end
local statLabel = Stub.byName(Stub.byName(stat.Frame, "Head"), "Label")
Stub.check(fits(statLabel) and statLabel.AutomaticSize ~= Enum.AutomaticSize.X, "a stat's label shrinks inside its card instead of growing past it")
Stub.check(fits(section.label), "a section title shrinks a little before it is cut")
Stub.check(fits(Stub.byName(eggs.Frame, "RarityName")) and fits(Stub.byName(Stub.byName(eggs.Frame, "Items"), "Name")), "item names and rarities shrink before they are cut")

local entry = Stub.byName(donut.Frame, "Entry")
Stub.equal(entry.Size.X.Scale, 1, "beside a donut, a legend entry is as wide as its column")
Stub.check(Stub.byName(entry, "Name").TextTruncate == Enum.TextTruncate.AtEnd, "and a long name is cut there")
Stub.check(Stub.byName(bars.Frame, "Legend"):FindFirstChildOfClass("UIListLayout").Wraps, "under a bar chart, the legend wraps")

local button = Stub.byName(open.Frame, "Button")
local label = Stub.byName(button, "Label")
Stub.place(button, 0, 0, 160, 36)
Stub.flush()
local cap = label:FindFirstChildOfClass("UISizeConstraint")
Stub.check(cap ~= nil and cap.MaxSize.X <= 160 - 24, "a button's label is never wider than the button")
Stub.check(label.TextTruncate == Enum.TextTruncate.AtEnd, "and is cut at the end when it would be")
local tabbed = window:Tab({ Title = "Combat" }):Section({ Title = "Aim", Tabs = { "Players", "Visual effects" } })
Stub.flush()
Stub.check(fits(tabbed.pageButtons["Visual effects"]), "a section's inner tabs shrink a long name before cutting it")
local places = section:Waypoints({ Title = "Saved places" })
Stub.flush()
local nameBox = Stub.byName(places.Frame, "PlaceName")
local base = nameBox.TextSize
Stub.place(nameBox, 0, 0, 120, 28)
nameBox.TextBounds = Vector2.new(200, 13)
nameBox.PlaceholderText = "Назовите это место"
Stub.flush()
Stub.check(nameBox.TextSize < base and nameBox.TextSize >= 11 and not nameBox.TextWrapped, "a placeholder longer than its box shrinks, on one line")
Stub.equal(nameBox.TextTruncate, Enum.TextTruncate.AtEnd, "and ends in an ellipsis past that")
nameBox.Text = "Spawn"
Stub.flush()
Stub.equal(nameBox.TextSize, base, "typed text keeps the box's own size")
window:Unload()
