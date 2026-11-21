-- An inventory to pick from: pets, weapons, eggs, fish. Each card shows a
-- picture, the item's name, how many the player has, and its rarity as a
-- coloured edge and word (the word is there so colour is never the only
-- sign). Searching filters by name; Sort orders by rarity, name or count.
--
-- Options: Items = { { Title, Image, Icon, Rarity, Count, Value,
-- Disabled } }, Rarities (see RARITIES), Multi, Default,
-- AllowNone, Search [true above 8 items], Sort ("Rarity" | "Name" |
-- "Count"), Columns (fixed count; fitted to the width when left out),
-- Height [260, then it scrolls].

local Create = require("../Core/Create")
local Icons = require("../Core/Icons")
local Motion = require("../Core/Motion")
local Row = require("./Row")
local Strings = require("../Core/Strings")
local Theme = require("../Core/Theme")

local ItemGrid = {}

-- Lowest first; sorting by rarity puts the last ones first. A hub's own
-- Rarities list ({ { Name, Role or Color } }) replaces these.
local RARITIES = {
	{ Name = "Common", Role = "textMuted" },
	{ Name = "Uncommon", Role = "success" },
	{ Name = "Rare", Role = "info" },
	{ Name = "Epic", Color = Color3.fromRGB(168, 102, 255) },
	{ Name = "Legendary", Role = "warning" },
	{ Name = "Mythic", Role = "danger" },
}
local GAP = 8
-- Cards aim for this width; the grid fits as many as the row allows.
local CARD_WIDTH = 84

function ItemGrid.new(container, options)
	local row = Row.new(container, options)
	local handle, scope = row.handle, row.scope
	local multi = options.Multi == true
	local rarities = if type(options.Rarities) == "table" then options.Rarities else RARITIES
	local rank, rarityOf = {}, {}
	for index, rarity in rarities do
		rank[rarity.Name] = index
		rarityOf[rarity.Name] = rarity
	end
	local items = options.Items or {}
	local picked = {}
	local query = ""
	local cards = {}

	local area = row.belowTitle()
	Create.list(area, "Vertical", 8)
	local searchBox
	if options.Search == true or (options.Search ~= false and #items > 8) then
		searchBox = Create.new("TextBox", {
			Name = "Search",
			Size = UDim2.new(1, 0, 0, row.reach),
			PlaceholderText = Strings.get("Search"),
			Text = "",
			TextSize = 13,
			ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Theme = { BackgroundColor3 = row.controlRole, TextColor3 = "text", PlaceholderColor3 = "textMuted" },
			Parent = area,
		})
		Create.corner(8, searchBox)
		Create.padding(searchBox, 10, 0)
		Create.stroke("stroke", searchBox)
	end
	local scroller = Create.new("ScrollingFrame", {
		Name = "Items",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		LayoutOrder = 1,
		Theme = { ScrollBarImageColor3 = "textMuted" },
		Parent = area,
	})
	local grid = Create.new("UIGridLayout", {
		CellPadding = UDim2.fromOffset(GAP, GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroller,
	})
	Create.padding(scroller, 1, 1, 6, 1)

	local maxHeight = tonumber(options.Height) or 260
	local function fit()
		local width = scroller.AbsoluteSize.X / row.library.scale - 8
		if width <= 0 then
			return
		end
		local columns = tonumber(options.Columns) or math.max(math.floor((width + GAP) / (CARD_WIDTH + GAP)), 2)
		local cell = (width - GAP * (columns - 1)) / columns
		grid.CellSize = UDim2.fromOffset(math.floor(cell), math.floor(cell + 34))
		local content = grid.AbsoluteContentSize.Y / row.library.scale
		scroller.Size = UDim2.new(1, 0, 0, math.min(content + 2, maxHeight))
	end
	scope:connect(scroller:GetPropertyChangedSignal("AbsoluteSize"), fit)
	scope:connect(grid:GetPropertyChangedSignal("AbsoluteContentSize"), fit)

	local function roleOf(item)
		local rarity = rarityOf[item.Rarity]
		return rarity, if rarity then rarity.Role else nil
	end

	local function paint(card)
		local on = picked[card.value] == true
		local rarity, role = roleOf(card.item)
		local edgeRole = if on then "accent" elseif card.hovered then "textMuted" else "stroke"
		if rarity and not on and not card.hovered then
			edgeRole = role
		end
		if rarity and rarity.Color and not on and not card.hovered then
			Theme.unbind(card.edge, "Color")
			card.edge.Color = rarity.Color
		else
			Theme.bind(card.edge, "Color", edgeRole or "stroke")
		end
		card.edge.Transparency = if on or card.hovered then 0 else 0.4
		Motion.tween(card.edge, "fast", { Thickness = if on then 2 else 1 })
		card.tick.Visible = on
	end

	local function valueOf(item)
		if item.Value ~= nil then
			return item.Value
		end
		return item.Title or item.Name
	end

	local function order()
		local list = table.clone(items)
		if options.Sort == "Name" then
			table.sort(list, function(a, b)
				return string.lower(tostring(a.Title or a.Name or "")) < string.lower(tostring(b.Title or b.Name or ""))
			end)
		elseif options.Sort == "Count" then
			table.sort(list, function(a, b)
				return (tonumber(a.Count) or 0) > (tonumber(b.Count) or 0)
			end)
		elseif options.Sort == "Rarity" then
			table.sort(list, function(a, b)
				return (rank[a.Rarity] or 0) > (rank[b.Rarity] or 0)
			end)
		end
		return list
	end

	local function filter()
		for _, card in cards do
			local name = string.lower(tostring(card.item.Title or card.item.Name or ""))
			card.frame.Visible = query == "" or string.find(name, query, 1, true) ~= nil
		end
	end

	local function build()
		for _, card in cards do
			card.frame:Destroy()
		end
		table.clear(cards)
		for index, item in order() do
			local value = valueOf(item)
			local rarity, role = roleOf(item)
			local frame = Create.new("TextButton", {
				Name = "Item",
				Text = "",
				LayoutOrder = index,
				AutoButtonColor = false,
				Theme = { BackgroundColor3 = row.controlRole },
				Parent = scroller,
			})
			Create.corner(10, frame)
			local edge = Create.stroke("stroke", frame)
			-- A wash of the rarity's colour from the bottom of the card.
			if rarity then
				local wash = Create.new("Frame", {
					Name = "Rarity",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 0.2,
					Parent = frame,
				}, {
					Create.new("UIGradient", {
						Rotation = 270,
						Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.82), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1) }),
					}),
				})
				Create.corner(10, wash)
				if rarity.Color then
					wash.BackgroundColor3 = rarity.Color
				else
					Theme.bind(wash, "BackgroundColor3", role)
				end
			end
			local picture = Create.new("ImageLabel", {
				Name = "Picture",
				Size = UDim2.new(1, -28, 1, -58),
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 12),
				ScaleType = Enum.ScaleType.Fit,
				Theme = { ImageColor3 = if item.Image then nil else "textMuted" },
				Parent = frame,
			})
			Icons.apply(picture, item.Image or item.Icon or "package")
			Create.fit(Create.new("TextLabel", {
				Name = "Name",
				Size = UDim2.new(1, -12, 0, 16),
				Position = UDim2.new(0, 6, 1, -36),
				TextSize = 12,
				Weight = "medium",
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = tostring(item.Title or item.Name or ""),
				Theme = { TextColor3 = "text" },
				Parent = frame,
			}), 9)
			local rarityLabel = Create.new("TextLabel", {
				Name = "RarityName",
				Size = UDim2.new(1, -12, 0, 14),
				Position = UDim2.new(0, 6, 1, -19),
				TextSize = 11,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = if item.Rarity then Strings.get(tostring(item.Rarity)) else "",
				Theme = { TextColor3 = role or "textMuted" },
				Parent = frame,
			})
			Create.fit(rarityLabel, 8)
			if rarity and rarity.Color then
				Theme.unbind(rarityLabel, "TextColor3")
				rarityLabel.TextColor3 = rarity.Color
			end
			if item.Count ~= nil then
				local count = Create.new("TextLabel", {
					Name = "Count",
					Size = UDim2.fromOffset(0, 18),
					AutomaticSize = Enum.AutomaticSize.X,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -6, 0, 6),
					TextSize = 11,
					Weight = "bold",
					Text = "x" .. tostring(item.Count),
					Theme = { BackgroundColor3 = "surface", TextColor3 = "text" },
					Parent = frame,
				})
				Create.corner(-1, count)
				Create.padding(count, 6, 0)
			end
			local tick = Create.new("Frame", {
				Name = "Picked",
				Size = UDim2.fromOffset(18, 18),
				Position = UDim2.fromOffset(6, 6),
				Visible = false,
				Theme = { BackgroundColor3 = "accent" },
				Parent = frame,
			})
			Create.corner(-1, tick)
			local check = Create.icon("check", 12, "onAccent", tick)
			check.AnchorPoint, check.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
			if item.Disabled then
				frame.Active = false
				picture.ImageTransparency = 0.6
			end
			local card = { frame = frame, edge = edge, tick = tick, item = item, value = value, hovered = false }
			table.insert(cards, card)
			scope:connect(frame.MouseEnter, function()
				card.hovered = true
				paint(card)
			end)
			scope:connect(frame.MouseLeave, function()
				card.hovered = false
				paint(card)
			end)
			scope:connect(frame.Activated, function()
				if item.Disabled or handle:IsLocked() then
					return
				end
				if multi then
					picked[value] = not picked[value] or nil
				elseif picked[value] then
					if options.AllowNone then
						picked[value] = nil
					end
				else
					table.clear(picked)
					picked[value] = true
				end
				for _, other in cards do
					paint(other)
				end
				row.fire(handle:Get())
			end)
			paint(card)
		end
		filter()
		fit()
	end

	if searchBox then
		scope:connect(searchBox:GetPropertyChangedSignal("Text"), function()
			query = string.lower(searchBox.Text)
			filter()
		end)
	end

	-- Picked values in the order the items are listed; one value or nil
	-- without Multi.
	function handle:Get()
		local list = {}
		for _, item in items do
			local value = valueOf(item)
			if picked[value] then
				table.insert(list, value)
			end
		end
		if multi then
			return list
		end
		return list[1]
	end

	function handle:Set(value)
		table.clear(picked)
		if multi and type(value) == "table" then
			for _, one in value do
				picked[one] = true
			end
		elseif value ~= nil then
			picked[value] = true
		end
		for _, card in cards do
			paint(card)
		end
		row.fire(self:Get())
	end

	-- Replaces the items, keeping picks that still exist.
	function handle:Refresh(newItems)
		items = newItems or {}
		local still = {}
		for _, item in items do
			local value = valueOf(item)
			if picked[value] then
				still[value] = true
			end
		end
		picked = still
		build()
	end

	-- Updates one item's count without rebuilding the grid.
	function handle:SetCount(value, count)
		for _, card in cards do
			if card.value == value then
				card.item.Count = count
				local label = card.frame:FindFirstChild("Count")
				if label then
					label.Text = "x" .. tostring(count)
				end
			end
		end
	end

	local default = options.Default
	if multi and type(default) == "table" then
		for _, one in default do
			picked[one] = true
		end
	elseif default ~= nil then
		picked[default] = true
	end
	build()
	return handle
end

return ItemGrid
