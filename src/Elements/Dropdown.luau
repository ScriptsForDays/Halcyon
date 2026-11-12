local Create = require("../Core/Create")
local Motion = require("../Core/Motion")
local Popup = require("../Components/Popup")
local Row = require("./Row")
local Theme = require("../Core/Theme")

local SEARCH_FROM = 8
local LIST_HEIGHT = 216

local Dropdown = {}

-- Options: Values, Default, Multi, AllowNone, Searchable, Placeholder, Width.
-- The value is one entry or nil; with Multi, an array in Values order.
function Dropdown.new(container, options)
	local row = Row.new(container, options, { button = true })
	local handle, scope, kit = row.handle, row.scope, row.kit
	local multi = options.Multi == true
	local values = table.clone(options.Values or {})
	local picked = {}
	local repaint

	local chip = Create.new("Frame", { Name = "Value", Theme = { BackgroundColor3 = row.controlRole } })
	row.adapt(chip, options.Width or 150, math.max(row.reach, 30))
	Create.corner(6, chip)
	Create.stroke("stroke", chip)
	local label = Create.new("TextLabel", {
		Size = UDim2.new(1, -34, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = "text" },
		Parent = chip,
	})
	local chevron = Create.icon("chevron-down", 14, "textMuted", chip)
	chevron.AnchorPoint = Vector2.new(1, 0.5)
	chevron.Position = UDim2.new(1, -8, 0.5, 0)

	row.onHover(function(active)
		local role = if active then "hover" else row.controlRole
		Theme.bind(chip, "BackgroundColor3", role, true)
		Motion.tween(chip, "fast", { BackgroundColor3 = Theme.color(role) })
	end, chip)

	local function selection()
		local list = {}
		for _, value in values do
			if picked[value] then
				table.insert(list, value)
			end
		end
		return list
	end

	local function draw()
		local list = selection()
		local text = options.Placeholder or "None"
		if #list == 1 or (#list == 2 and multi) then
			local names = {}
			for index, value in list do
				names[index] = tostring(value)
			end
			text = table.concat(names, ", ")
		elseif #list > 2 then
			text = #list .. " selected"
		end
		label.Text = text
		if repaint then
			repaint()
		end
	end

	-- Keeps only values the dropdown still offers.
	local function store(value)
		table.clear(picked)
		local wanted = if multi and type(value) == "table" then value else { value }
		for _, item in wanted do
			if table.find(values, item) then
				picked[item] = true
				if not multi then
					break
				end
			end
		end
		draw()
	end

	function handle:Get()
		local list = selection()
		return if multi then list else list[1]
	end

	function handle:Set(value)
		store(value)
		row.fire(self:Get())
	end

	-- Replaces the choices. Anything picked that is no longer offered is dropped.
	function handle:Refresh(newValues)
		local kept = selection()
		values = table.clone(newValues)
		Popup.close(kit)
		store(if multi then kept else kept[1])
	end

	scope:connect(row.frame.Activated, function()
		local popup = Popup.toggle(kit, chip, {
			Width = math.max(chip.AbsoluteSize.X / kit.scale, 190),
			OnClose = function()
				repaint = nil
				Motion.tween(chevron, "fast", { Rotation = 0 })
			end,
		})
		if not popup then
			return
		end
		Motion.tween(chevron, "fast", { Rotation = 180 })
		local session = popup.scope
		local height = if kit.touch then 40 else 32
		local items = {}

		local search
		if options.Searchable or (options.Searchable == nil and #values > SEARCH_FROM) then
			search = Create.new("TextBox", {
				Name = "Search",
				Size = UDim2.new(1, 0, 0, height),
				PlaceholderText = "Search",
				TextSize = 13,
				Theme = { BackgroundColor3 = "raised", TextColor3 = "text" },
				Parent = popup.frame,
			})
			Create.corner(6, search)
			Create.padding(search, 10, 0)
		end

		local list = Create.new("ScrollingFrame", {
			Name = "Options",
			Size = UDim2.new(1, 0, 0, math.min(#values * (height + 2), LIST_HEIGHT)),
			LayoutOrder = 1,
			Parent = popup.frame,
		})
		Create.list(list, "Vertical", 2)

		for index, value in values do
			local item = Create.new("TextButton", {
				Name = "Option",
				Size = UDim2.new(1, 0, 0, height),
				LayoutOrder = index,
				BackgroundTransparency = 1,
				Theme = { BackgroundColor3 = "hover" },
				Parent = list,
			})
			Create.corner(6, item)
			local text = Create.new("TextLabel", {
				Size = UDim2.new(1, -44, 1, 0),
				Position = UDim2.fromOffset(10, 0),
				Text = tostring(value),
				TextSize = 13,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Theme = { TextColor3 = "text" },
				Parent = item,
			})
			-- The mark says what kind of choice this is before anything is
			-- picked: a round radio for one value, a square box for several.
			local mark = Create.new("Frame", {
				Name = "Mark",
				Size = UDim2.fromOffset(18, 18),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				BackgroundTransparency = 1,
				Theme = { BackgroundColor3 = "accent" },
				Parent = item,
			})
			Create.corner(if multi then 5 else -1, mark)
			local edge = Create.stroke("stroke", mark, 1.5)
			local glyph
			if multi then
				glyph = Create.icon("check", 12, "onAccent", mark)
			else
				glyph = Create.new("Frame", { Name = "Dot", Size = UDim2.fromOffset(8, 8), Theme = { BackgroundColor3 = "accent" }, Parent = mark })
				Create.corner(-1, glyph)
			end
			glyph.AnchorPoint = Vector2.new(0.5, 0.5)
			glyph.Position = UDim2.fromScale(0.5, 0.5)
			local entry = { button = item, text = text, mark = mark, edge = edge, glyph = glyph, value = value, on = false }
			items[index] = entry

			-- A picked option keeps a light accent wash; hovering deepens it.
			session:connect(item.MouseEnter, function()
				Motion.tween(item, "fast", { BackgroundTransparency = if entry.on then 0.8 else 0 })
			end)
			session:connect(item.MouseLeave, function()
				Motion.tween(item, "fast", { BackgroundTransparency = if entry.on then 0.88 else 1 })
			end)
			session:connect(item.Activated, function()
				if multi then
					local chosen = selection()
					local found = table.find(chosen, value)
					if found then
						table.remove(chosen, found)
					else
						table.insert(chosen, value)
					end
					handle:Set(chosen)
				else
					handle:Set(if picked[value] and options.AllowNone then nil else value)
					popup.close()
				end
			end)
		end

		-- Selected shows as a filled mark, an accent wash and a heavier
		-- weight together, never colour alone.
		function repaint()
			for _, item in items do
				local on = picked[item.value] == true
				item.on = on
				item.glyph.Visible = on
				item.text.FontFace = Create.font(if on then "bold" else "regular")
				Theme.bind(item.button, "BackgroundColor3", if on then "accent" else "hover")
				item.button.BackgroundTransparency = if on then 0.88 else 1
				Theme.bind(item.edge, "Color", if on then "accent" else "stroke")
				if multi then
					item.mark.BackgroundTransparency = if on then 0 else 1
				end
			end
		end
		repaint()

		if search then
			session:connect(search:GetPropertyChangedSignal("Text"), function()
				local query = string.lower(search.Text)
				for _, item in items do
					item.button.Visible = query == "" or string.find(string.lower(tostring(item.value)), query, 1, true) ~= nil
				end
			end)
		end
	end)

	local default = options.Default
	if default == nil and not multi and not options.AllowNone and options.Placeholder == nil then
		default = values[1]
	end
	store(default)
	return handle
end

return Dropdown
