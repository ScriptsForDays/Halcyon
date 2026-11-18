local Create = require("../Core/Create")
local Row = require("./Row")
local Strings = require("../Core/Strings")
local Theme = require("../Core/Theme")

local Tags = {}

-- Words the player adds by typing and pressing Enter, each shown as a chip
-- with an × to remove it: a whitelist of names, keywords to watch for.
-- Options: Default (a list), Placeholder, Suggestions (a list offered as
-- the player types), Max, AllowDuplicates. Get returns the list.
function Tags.new(container, options)
	local row = Row.new(container, options)
	local handle, scope = row.handle, row.scope
	local max = tonumber(options.Max)
	local tags = {}
	for _, tag in options.Default or {} do
		if type(tag) == "string" and tag ~= "" then
			table.insert(tags, tag)
		end
	end

	local below = row.belowTitle()
	Create.list(below, "Vertical", 6)
	local field = Create.new("Frame", {
		Name = "Field",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Theme = { BackgroundColor3 = row.controlRole },
		Parent = below,
	})
	Create.corner(8, field)
	local edge = Create.stroke("stroke", field)
	Create.padding(field, 6)
	Create.list(field, "Horizontal", 6, { Wraps = true, VerticalAlignment = Enum.VerticalAlignment.Center })
	local box = Create.new("TextBox", {
		Name = "Entry",
		Size = UDim2.fromOffset(120, 26),
		PlaceholderText = options.Placeholder or Strings.get("Type and press Enter"),
		TextSize = 13,
		LayoutOrder = 1e6,
		ClearTextOnFocus = false,
		Theme = { TextColor3 = "text" },
		Parent = field,
	}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Grow }) })
	Create.padding(box, 4, 0)
	local suggestions = Create.new("Frame", { Name = "Suggestions", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Visible = false, Parent = below })
	Create.list(suggestions, "Horizontal", 6, { Wraps = true })

	local chips = {}
	local add, remove

	local function draw()
		for _, chip in chips do
			chip:Destroy()
		end
		table.clear(chips)
		for index, tag in tags do
			local chip = Create.new("Frame", {
				Name = "Tag",
				Size = UDim2.fromOffset(0, 26),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = index,
				BackgroundTransparency = 0.85,
				Theme = { BackgroundColor3 = "accent" },
				Parent = field,
			})
			Create.corner(-1, chip)
			Create.padding(chip, 10, 0, 4, 0)
			Create.list(chip, "Horizontal", 4, { VerticalAlignment = Enum.VerticalAlignment.Center })
			Create.new("TextLabel", {
				Name = "Text",
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = tag,
				TextSize = 12,
				Weight = "medium",
				Theme = { TextColor3 = "accent" },
				Parent = chip,
			})
			local cross = Create.new("TextButton", { Name = "Remove", Size = UDim2.fromOffset(20, 20), LayoutOrder = 1, Parent = chip })
			local glyph = Create.icon("x", 12, "accent", cross)
			glyph.AnchorPoint, glyph.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
			scope:connect(cross.Activated, function()
				remove(index)
			end)
			table.insert(chips, chip)
		end
		box.Visible = not (max and #tags >= max)
	end

	local function changed()
		draw()
		handle.SearchExtra = table.concat(tags, " ")
		row.fire(table.clone(tags))
	end

	function add(text)
		text = string.match(tostring(text or ""), "^%s*(.-)%s*$")
		if text == "" or (max and #tags >= max) then
			return false
		end
		if not options.AllowDuplicates then
			for _, tag in tags do
				if string.lower(tag) == string.lower(text) then
					return false
				end
			end
		end
		table.insert(tags, text)
		changed()
		return true
	end

	function remove(index)
		if tags[index] then
			table.remove(tags, index)
			changed()
		end
	end

	local function suggest()
		for _, child in suggestions:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local query = string.lower(box.Text)
		local shown = 0
		if query ~= "" and type(options.Suggestions) == "table" then
			for _, word in options.Suggestions do
				local taken = table.find(tags, word) ~= nil
				if not taken and shown < 6 and string.find(string.lower(word), query, 1, true) then
					shown += 1
					local option = Create.new("TextButton", {
						Name = "Suggestion",
						Size = UDim2.fromOffset(0, 24),
						AutomaticSize = Enum.AutomaticSize.X,
						Text = word,
						TextSize = 12,
						LayoutOrder = shown,
						Theme = { BackgroundColor3 = row.controlRole, TextColor3 = "text" },
						Parent = suggestions,
					})
					Create.corner(-1, option)
					Create.padding(option, 10, 0)
					Create.stroke("stroke", option)
					scope:connect(option.Activated, function()
						add(word)
						box.Text = ""
					end)
				end
			end
		end
		suggestions.Visible = shown > 0
	end

	scope:connect(box:GetPropertyChangedSignal("Text"), suggest)
	scope:connect(box.Focused, function()
		Theme.bind(edge, "Color", "accent")
	end)
	scope:connect(box.FocusLost, function(enter)
		Theme.bind(edge, "Color", "stroke")
		if enter and add(box.Text) then
			box.Text = ""
			box:CaptureFocus()
		end
	end)

	function handle:Get()
		return table.clone(tags)
	end

	function handle:Set(list)
		table.clear(tags)
		for _, tag in if type(list) == "table" then list else {} do
			if type(tag) == "string" and tag ~= "" then
				table.insert(tags, tag)
			end
		end
		changed()
	end

	function handle:Add(text)
		return add(text)
	end

	function handle:Remove(text)
		local index = table.find(tags, text)
		if index then
			remove(index)
		end
	end

	draw()
	handle.SearchExtra = table.concat(tags, " ")
	return handle
end

return Tags
