-- A grid of cards to pick from, each with an icon, a name and an optional
-- line under it: modes, teleport spots, loadouts.
--
-- Options: Items (see Options.luau; Icon, Image and Description are shown),
-- Columns (default 3; fewer on a narrow row), Multi, Default, AllowNone,
-- Height (each card's height).

local Create = require("../Core/Create")
local Motion = require("../Core/Motion")
local Options = require("./Options")
local Row = require("./Row")
local Theme = require("../Core/Theme")

local GAP = 8

local Tiles = {}

function Tiles.new(container, options)
	local row = Row.new(container, options)
	local handle, scope = row.handle, row.scope
	local multi = options.Multi == true
	local entries, values = Options.entries(options.Items or options.Values)
	local picked = {}
	local cards = {}
	local columns = math.clamp(tonumber(options.Columns) or 3, 1, 6)
	local height = tonumber(options.Height) or (if entries[1] and entries[1].description then 84 else 68)

	local area = row.belowTitle()
	local grid = Create.new("UIGridLayout", {
		CellPadding = UDim2.fromOffset(GAP, GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = area,
	})
	-- Cell widths follow the row, and a narrow row drops to two columns.
	local function fit()
		local width = area.AbsoluteSize.X / row.library.scale
		local shown = if width > 0 and width < 300 then math.min(columns, 2) else columns
		-- One pixel spare: rounding can otherwise push the last card to a new line.
		grid.CellSize = UDim2.new(1 / shown, -GAP * (shown - 1) / shown - 1, 0, height)
	end
	scope:connect(area:GetPropertyChangedSignal("AbsoluteSize"), fit)
	fit()

	local function draw(timing)
		for _, card in cards do
			local on = picked[card.value] == true
			Theme.bind(card.edge, "Color", if on then "accent" elseif card.hovered then "textMuted" else "stroke")
			Motion.tween(card.edge, timing, { Thickness = if on then 1.5 else 1 })
			Theme.bind(card.frame, "BackgroundColor3", if on then "accent" else row.controlRole)
			card.frame.BackgroundTransparency = if on then 0.86 else 0
			if card.icon then
				Theme.bind(card.icon, "ImageColor3", if on then "accent" else "textMuted")
			end
			card.tick.Visible = on
		end
	end

	function handle:Get()
		local list = Options.ordered(values, picked)
		return if multi then list else list[1]
	end

	function handle:Set(value)
		Options.pick(values, picked, value, multi)
		draw("fast")
		row.fire(self:Get())
	end

	for index, entry in entries do
		if entry.heading then
			continue
		end
		local frame = Create.new("TextButton", {
			Name = "Tile",
			LayoutOrder = index,
			Theme = { BackgroundColor3 = row.controlRole },
			Parent = area,
		})
		Create.corner(8, frame)
		local card = { frame = frame, value = entry.value, edge = Create.stroke("stroke", frame), hovered = false }
		-- The card itself has no layout, so the corner tick can sit over it.
		local content = Create.new("Frame", { Name = "Content", Size = UDim2.fromScale(1, 1), Parent = frame })
		Create.padding(content, 8, 10)
		Create.list(content, "Vertical", 4, { HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center })
		if entry.icon or entry.image then
			card.icon = Create.new("ImageLabel", {
				Name = "Icon",
				Size = UDim2.fromOffset(22, 22),
				Icon = entry.icon,
				Theme = if entry.icon then { ImageColor3 = "textMuted" } else nil,
				Parent = content,
			})
			if entry.image then
				card.icon.Image = entry.image
			end
		end
		Create.new("TextLabel", {
			Name = "Title",
			Size = UDim2.new(1, 0, 0, 16),
			Text = entry.text,
			TextSize = 13,
			Weight = "medium",
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 1,
			Theme = { TextColor3 = if entry.disabled then "textMuted" else "text" },
			Parent = content,
		})
		if entry.description then
			Create.new("TextLabel", {
				Name = "Description",
				Size = UDim2.new(1, 0, 0, 14),
				Text = tostring(entry.description),
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = 2,
				Theme = { TextColor3 = "textMuted" },
				Parent = content,
			})
		end
		-- A tick in the corner says picked without relying on colour alone.
		card.tick = Create.new("Frame", {
			Name = "Tick",
			Size = UDim2.fromOffset(16, 16),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			Visible = false,
			ZIndex = 2,
			Theme = { BackgroundColor3 = "accent" },
			Parent = frame,
		})
		Create.corner(-1, card.tick)
		local mark = Create.icon("check", 10, "onAccent", card.tick)
		mark.AnchorPoint, mark.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		table.insert(cards, card)

		if entry.disabled then
			frame.AutoButtonColor = false
			frame.BackgroundTransparency = 0.5
			continue
		end
		scope:connect(frame.MouseEnter, function()
			card.hovered = true
			draw("fast")
		end)
		scope:connect(frame.MouseLeave, function()
			card.hovered = false
			draw("fast")
		end)
		scope:connect(frame.Activated, function()
			if multi then
				local chosen = Options.ordered(values, picked)
				local found = table.find(chosen, entry.value)
				if found then
					table.remove(chosen, found)
				else
					table.insert(chosen, entry.value)
				end
				handle:Set(chosen)
			else
				handle:Set(if picked[entry.value] and options.AllowNone then nil else entry.value)
			end
		end)
	end

	local default = options.Default
	if default == nil and not multi and not options.AllowNone then
		default = values[1]
	end
	Options.pick(values, picked, default, multi)
	draw(nil)
	return handle
end

return Tiles
