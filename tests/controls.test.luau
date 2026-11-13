-- The control looks and the controls added with the style system.
local Internal = Halcyon.Internal
local library = Internal.library

local function find(root, name)
	return Stub.byName(root, name)
end

local window = Halcyon:CreateWindow({ Title = "Controls Hub", Folder = "ControlsHub" })
local tab = window:Tab({ Title = "Combat", Icon = "sword" })
local section = tab:Section({ Title = "Looks" })

-- Every toggle look builds, switches and reports its value.
for _, look in Halcyon:GetStyles("Toggle") do
	local seen
	local toggle = section:Toggle({ Title = "Toggle " .. look, Style = look, Callback = function(on)
		seen = on
	end })
	toggle:Set(true)
	Stub.flush()
	Stub.check(toggle:Get() == true and seen == true, "toggle look " .. look .. " switches on")
	toggle:Set(false)
	Stub.check(toggle:Get() == false, "toggle look " .. look .. " switches off")
end
Stub.check(#Halcyon:GetStyles("Toggle") >= 10, "there are at least ten toggle looks")
local labelled = section:Toggle({ Title = "Words", Style = "Labelled" })
local word = find(labelled.Frame, "State")
Stub.equal(word.Text, "OFF", "a labelled switch reads OFF while off")
labelled:Set(true)
Stub.equal(word.Text, "ON", "and ON while on")
local slim = section:Toggle({ Title = "Slim", Style = "Slim" })
Stub.check(find(slim.Frame, "Rail") ~= nil, "a slim switch has a thin rail under its thumb")

-- Every slider look builds and the display options format the value.
for _, look in Halcyon:GetStyles("Slider") do
	local slider = section:Slider({ Title = "Slider " .. look, Style = look, Min = 0, Max = 10, Default = 4 })
	slider:Set(7)
	Stub.equal(slider:Get(), 7, "slider look " .. look .. " keeps its value")
end
local bare = section:Slider({ Title = "Bare", Style = "Bare", Min = 0, Max = 10 })
Stub.check(find(bare.Frame, "Knob") == nil, "a bare slider has no knob")
local ticks = section:Slider({ Title = "Ticks", Style = "Ticks", Min = 0, Max = 5 })
local count = 0
for _, child in find(ticks.Frame, "Rail"):GetChildren() do
	if child.Name == "Tick" then
		count += 1
	end
end
Stub.equal(count, 6, "a five-step slider has a mark at each step")
local percent = section:Slider({ Title = "Volume", Min = 0, Max = 200, Default = 50, Percent = true, Display = "Text" })
Stub.equal(find(percent.Frame, "Value").Text, "25%", "Percent shows the share of the range")
local money = section:Slider({ Title = "Cash", Min = 0, Max = 10, Default = 3, Prefix = "$", Display = "Fraction" })
Stub.equal(find(money.Frame, "Value").Text, "$3 / $10", "Fraction shows the maximum, with the prefix")
local formatted = section:Slider({ Title = "Speed", Min = 0, Max = 10, Default = 2, Format = function(value)
	return value * 10 .. " studs"
end })
Stub.equal(find(formatted.Frame, "Value").Text, "20 studs", "Format writes the value")
local block = section:Slider({ Title = "Block", Style = "Block", Min = 0, Max = 10, Default = 5 })
Stub.equal(find(block.Frame, "Inside").Text, "5", "a block slider shows its value on the bar")
local marked = section:Slider({ Title = "Marked", Min = 0, Max = 10, Default = 5, DefaultMarker = true })
Stub.check(find(marked.Frame, "DefaultMark") ~= nil, "DefaultMarker marks the default")

-- Buttons: looks, confirm, hold, loading and the done flash.
for _, look in Halcyon:GetStyles("Button") do
	local button = section:Button({ Title = "Button " .. look, Variant = look })
	Stub.check(button.Frame ~= nil, "button look " .. look .. " builds")
end
local runs = 0
local confirm = section:Button({ Title = "Reset", Variant = "Danger", Confirm = true, Callback = function()
	runs += 1
end })
local target = find(confirm.Frame, "Button")
Stub.click(target)
Stub.equal(runs, 0, "a confirm button does not run on the first press")
Stub.equal(find(target, "Label").Text, "Press again to confirm", "it asks for a second press")
Stub.click(target)
Stub.flush()
Stub.equal(runs, 1, "the second press runs it")
Stub.equal(find(target, "Label").Text, "Reset", "and the wording returns")
Stub.click(target)
Stub.advance(3.5)
Stub.equal(find(target, "Label").Text, "Reset", "an armed button disarms after three seconds")

local held = 0
local hold = section:Button({ Title = "Hold me", Variant = "Filled", Hold = 1, Callback = function()
	held += 1
end })
local holdTarget = find(hold.Frame, "Button")
local press = { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(0, 0, 0) }
holdTarget.InputBegan:Fire(press)
Stub.advance(0.5)
holdTarget.InputEnded:Fire(press)
Stub.advance(1)
Stub.equal(held, 0, "letting go early does not run a hold button")
holdTarget.InputBegan:Fire(press)
Stub.advance(1.1)
Stub.equal(held, 1, "holding for the full time runs it")

local loading = section:Button({ Title = "Fetch", Variant = "Soft" })
loading:SetLoading(true, "Fetching")
Stub.check(loading:IsLoading(), "a button can show it is busy")
Stub.equal(find(loading.Frame, "Label").Text, "Fetching", "with its own wording")
loading:SetLoading(false)
Stub.equal(find(loading.Frame, "Label").Text, "Fetch", "and goes back after")

local done = section:Button({ Title = "Save", ShowDone = true, Callback = function() end })
done:Press()
Stub.flush()
Stub.check(Stub.find(done.Frame, function(instance)
	return instance:GetAttribute("HalcyonIcon") == "check"
end) ~= nil, "ShowDone flashes a tick after the callback succeeds")
local failed = section:Button({ Title = "Break", ShowDone = true, Callback = function()
	error("nope")
end })
failed:Press()
Stub.flush()
Stub.check(Stub.find(failed.Frame, function(instance)
	return instance:GetAttribute("HalcyonIcon") == "x"
end) ~= nil, "and a cross when it fails")

-- Inputs: looks, clear, counter and password.
for _, look in Halcyon:GetStyles("Input") do
	local input = section:Input({ Title = "Input " .. look, Style = look })
	input:Set("hello")
	Stub.equal(input:Get(), "hello", "input look " .. look .. " keeps its text")
end
local secret = section:Input({ Title = "Key", Password = true, Default = "abc" })
local box = find(secret.Frame, "Input")
Stub.equal(box.Text, string.rep("\u{2022}", 3), "a password shows as dots")
Stub.equal(secret:Get(), "abc", "but keeps its real value")
local counted = section:Input({ Title = "Name", MaxLength = 10, Counter = true, Clearable = true, Default = "Bob" })
Stub.equal(find(counted.Frame, "Counter").Text, "3/10", "the counter shows characters used")
Stub.click(find(counted.Frame, "Action"))
Stub.equal(counted:Get(), "", "the clear button empties the field")
local area = section:Input({ Title = "Notes", MultiLine = true, Lines = 5 })
Stub.check(find(area.Frame, "Input").MultiLine == true, "MultiLine makes a text area")

-- Dropdowns: rich options, looks and players.
local rich = section:Dropdown({
	Title = "Weapon",
	Values = {
		{ Heading = "Melee" },
		{ Text = "Sword", Icon = "sword", Description = "Close range" },
		{ Text = "Axe", Disabled = true },
		{ Heading = "Ranged" },
		{ Text = "Bow", Value = "bow" },
	},
})
Stub.equal(rich:Get(), "Sword", "a heading is never the default")
rich:Set("bow")
Stub.equal(rich:Get(), "bow", "an option's Value is what the dropdown reports")
rich:Set("Melee")
Stub.equal(rich:Get(), nil, "headings cannot be picked")
local chips = section:Dropdown({ Title = "Targets", Multi = true, Style = "Chips", Values = { "A", "B", "C" }, Default = { "A", "C" } })
local shown = 0
for _, child in Stub.byName(chips.Frame, "Below"):GetChildren() do
	if child.Name == "Chip" then
		shown += 1
	end
end
Stub.equal(shown, 2, "the chips look shows each picked value")
local players = section:Dropdown({ Title = "Player", Players = true })
Stub.equal(players:Get(), "TestUser", "a player dropdown lists the server's players")
local others = section:Dropdown({ Title = "Others", Players = true, ExcludeSelf = true, AllowNone = true })
Stub.equal(others:Get(), nil, "ExcludeSelf leaves the local player out")
local inline = section:Dropdown({ Title = "Inline", Style = "Inline", Values = { "One", "Two" } })
Stub.click(inline.Frame)
Stub.check(Stub.byText(inline.Frame, "Two") ~= nil, "an inline dropdown opens inside its row")

-- Radio, checklist, chips and tiles.
local radio = section:Radio({ Title = "Mode", Values = { "Safe", "Fast" } })
Stub.equal(radio:Get(), "Safe", "a radio group starts on its first option")
Stub.click(Stub.byText(radio.Frame, "Fast"))
Stub.equal(radio:Get(), "Fast", "pressing an option picks it")
local list = section:Checklist({ Title = "Loot", Values = { "Gold", "Gems", "Keys" }, SelectAll = true })
Stub.equal(#list:Get(), 0, "a checklist starts empty")
Stub.click(Stub.byText(list.Frame, "Select all"))
Stub.equal(#list:Get(), 3, "Select all picks every option")
Stub.click(Stub.byText(list.Frame, "Gems"))
Stub.equal(table.concat(list:Get(), ","), "Gold,Keys", "pressing one option leaves the others")
Stub.click(Stub.byText(list.Frame, "Select all"))
Stub.equal(#list:Get(), 3, "Select all with some picked picks the rest")
Stub.click(Stub.byText(list.Frame, "Select all"))
Stub.equal(#list:Get(), 0, "and again clears them")
local pills = section:Chips({ Title = "Tags", Values = { "PvP", "PvE" }, Multi = true })
Stub.click(Stub.byText(pills.Frame, "PvE"))
Stub.equal(pills:Get()[1], "PvE", "chips pick like a checklist")
local tiles = section:Tiles({ Title = "Map", Items = { { Title = "Lobby", Icon = "house" }, { Title = "Arena", Icon = "swords" } } })
Stub.equal(tiles:Get(), "Lobby", "tiles start on the first card")
Stub.click(Stub.byText(tiles.Frame, "Arena"))
Stub.equal(tiles:Get(), "Arena", "pressing a card picks it")

-- Rating, accordion, status, countdown, table, buttons and space.
local rating = section:Rating({ Title = "Rate", Default = 2 })
Stub.equal(rating:Get(), 2, "a rating keeps its default")
rating:Set(9)
Stub.equal(rating:Get(), 5, "and never goes past its maximum")
local faq = section:Accordion({ Title = "How do I farm?", Content = "Stand near the field." })
Stub.check(not find(faq.Frame, "Below").Visible, "an accordion starts closed")
Stub.click(faq.Frame)
Stub.check(find(faq.Frame, "Below").Visible, "pressing it opens it")
Stub.check(string.find(faq.SearchText, "field", 1, true) ~= nil, "its content is searchable")
local status = section:Status({ Title = "Server", Status = "Online", Kind = "success", Pulse = true })
status:SetStatus("Lagging", "warning")
Stub.equal(find(status.Frame, "Words").Text, "Lagging", "a status pill reports its words")
local ended = false
local timer = section:Countdown({ Title = "Boss", Seconds = 3, Done = "Spawned", Callback = function()
	ended = true
end })
Stub.check(timer:Get() > 0, "a countdown counts")
local grid = section:Table({ Columns = { "Name", { Title = "Kills", Align = "Right" } }, Rows = { { "b", 2 }, { "a", 10 } } })
Stub.equal(#grid:Get(), 2, "a table keeps its rows")
grid:AddRow({ "c", 1 })
Stub.equal(#grid:Get(), 3, "rows can be added")
Stub.click(Stub.byText(grid.Frame, "KILLS"))
local first = Stub.find(find(grid.Frame, "Body"), function(instance)
	return instance.Name == "Line" and instance.LayoutOrder == 1
end)
Stub.check(first ~= nil and Stub.byText(first, "c") ~= nil, "pressing a heading sorts by it, numbers as numbers")
grid:Clear()
Stub.check(find(grid.Frame, "Empty").Visible, "an empty table says so")
local pressed
local group = section:Buttons({ Buttons = { { Title = "Save", Callback = function()
	pressed = "Save"
end }, { Title = "Load" } } })
Stub.click(Stub.byText(group.Frame, "Save"))
Stub.flush()
Stub.equal(pressed, "Save", "a button group runs each button's callback")
local buttonRow = find(group.Frame, "Buttons")
Stub.check(buttonRow:FindFirstChildOfClass("UIListLayout").Wraps, "a button group wraps when its buttons can't share one line")
Stub.equal(group.Buttons[1]:FindFirstChildOfClass("UIFlexItem").FlexMode, Enum.UIFlexMode.Grow, "and each button grows from its own width instead of being squeezed")
local space = section:Space({ Height = 20 })
Stub.equal(space.Frame.Size.Y.Offset, 20, "Space adds room of the height given")
local callout = section:Label({ Title = "Careful", Style = "Warning" })
Stub.check(find(callout.Frame, "Callout") ~= nil, "a warning label is a callout")
callout:SetKind("Info")
Stub.equal(find(callout.Frame, "Icon"):GetAttribute("HalcyonIcon"), "info", "and can change kind")

-- Date picker and keybind mode picker.
local date = section:DatePicker({ Title = "Event", Default = { Year = 2026, Month = 2, Day = 31 }, Time = true })
Stub.equal(date:Get().Day, 28, "a date past the month's end is brought back into it")
date:Set({ Month = 3, Day = 15, Hour = 25 })
Stub.equal(date:Get().Hour, 23, "hours stay within the day")
Stub.check(type(date:GetTimestamp()) == "number", "a date gives a timestamp")
local key = section:Keybind({ Title = "Dash", Default = Enum.KeyCode.Q, ModePicker = true, Style = "Keycap" })
key:SetMode("Hold")
Stub.equal(key:GetMode(), "Hold", "the mode can change after creation")
key:SetMode("Sideways")
Stub.equal(key:GetMode(), "Hold", "an unknown mode is ignored")

-- Colour picker: the palette and recent colours.
local paint = section:ColorPicker({ Title = "Tint", Palette = true })
paint:Set(Color3.new(1, 0, 0))
Stub.check(library.recentColors ~= nil and library.recentColors[1]:ToHex() == "ff0000", "a picked colour is remembered for the Recent row")

-- Section-wide checks that every new kind is searchable and unloads.
window:Search("lagging")
Stub.check(status.Frame.Visible, "search finds a status by its words")
window:Search("")
Stub.advance(4)
Stub.check(ended, "the countdown runs its callback at zero")
window:Unload()
Stub.check(not Stub.find(game, function(instance)
	return instance.Name == "Spinner" and instance.Parent ~= nil and instance:FindFirstAncestor("Controls Hub") ~= nil
end), "unloading leaves nothing behind")
