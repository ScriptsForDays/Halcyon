local Players = game:GetService("Players")

local Create = require("../Core/Create")
local Motion = require("../Core/Motion")
local Options = require("./Options")
local Popup = require("../Components/Popup")
local Row = require("./Row")
local Styles = require("../Core/Styles")
local Theme = require("../Core/Theme")

local SEARCHABLE_FROM = 8
local LIST_HEIGHT = 216

-- Dropdown looks (kind "Dropdown").
--   Box      a boxed value with a chevron; the list opens in a popup
--   Minimal  the value and chevron with no box
--   Chips    picked values shown as removable chips under the title
--   Inline   the list opens inside the row instead of a popup
Styles.register("Dropdown", "Box", { box = true })
Styles.register("Dropdown", "Minimal", {})
Styles.register("Dropdown", "Chips", { box = true, chips = true })
Styles.register("Dropdown", "Inline", { box = true, inline = true })

local Dropdown = {}

local entriesFrom = Options.entries

-- The players in the server, by name, with their avatar.
local function playerOptions(excludeSelf)
	local list = {}
	for _, player in Players:GetPlayers() do
		if not (excludeSelf and player == Players.LocalPlayer) then
			table.insert(list, {
				Value = player.Name,
				Text = if player.DisplayName ~= player.Name then `{player.DisplayName} (@{player.Name})` else player.Name,
				Image = `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=48&h=48`,
			})
		end
	end
	table.sort(list, function(a, b)
		return string.lower(a.Value) < string.lower(b.Value)
	end)
	return list
end

-- Options: Values, Default, Multi, AllowNone, Searchable, Placeholder,
-- Width, Style (a Dropdown look), Players (the server's players; with
-- ExcludeSelf to leave the local player out). The value is one entry or
-- nil; with Multi, an array in Values order.
function Dropdown.new(container, options)
	local row = Row.new(container, options, { button = true })
	local handle, scope, library = row.handle, row.scope, row.library
	local multi = options.Multi == true
	local look = Styles.pick("Dropdown", options.Style, row.window)
	local source = if options.Players then playerOptions(options.ExcludeSelf) else options.Values or {}
	local entries, values = entriesFrom(source)
	local picked = {}
	local repaint, inlineList

	local chip = Create.new("Frame", {
		Name = "Value",
		BackgroundTransparency = if look.box then 0 else 1,
		Theme = { BackgroundColor3 = row.controlRole },
	})
	row.placeControl(chip, options.Width or (if look.box then 150 else 120), math.max(row.reach, 30))
	if look.box then
		Create.corner(6, chip)
		Create.stroke("stroke", chip)
	end
	local label = Create.new("TextLabel", {
		Size = UDim2.new(1, if look.box then -34 else -22, 1, 0),
		Position = UDim2.fromOffset(if look.box then 10 else 0, 0),
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = if look.box then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
		Theme = { TextColor3 = if look.box then "text" else "textMuted" },
		Parent = chip,
	})
	local chevron = Create.icon("chevron-down", 14, "textMuted", chip)
	chevron.AnchorPoint = Vector2.new(1, 0.5)
	chevron.Position = UDim2.new(1, if look.box then -8 else 0, 0.5, 0)

	row.onHover(function(active)
		if look.box then
			local role = if active then "hover" else row.controlRole
			Theme.bind(chip, "BackgroundColor3", role, true)
			Motion.tween(chip, "fast", { BackgroundColor3 = Theme.color(role) })
		else
			Theme.bind(label, "TextColor3", if active then "text" else "textMuted")
		end
	end, chip)

	-- Chips: each picked value as a small pill under the title, with a
	-- cross that removes it.
	local chipArea
	if look.chips and multi then
		chipArea = row.belowTitle()
		Create.list(chipArea, "Horizontal", 6, { Wraps = true, VerticalAlignment = Enum.VerticalAlignment.Top })
		local layout = chipArea:FindFirstChildOfClass("UIListLayout")
		layout.Padding = UDim.new(0, 6)
	end

	local function textOf(value)
		for _, entry in entries do
			if entry.value == value then
				return entry.text
			end
		end
		return tostring(value)
	end

	local function selection()
		local list = {}
		for _, value in values do
			if picked[value] then
				table.insert(list, value)
			end
		end
		return list
	end

	local drawChips
	local function draw()
		local list = selection()
		local text = options.Placeholder or "None"
		if #list == 1 or (#list == 2 and multi) then
			local names = {}
			for index, value in list do
				names[index] = textOf(value)
			end
			text = table.concat(names, ", ")
		elseif #list > 2 then
			text = #list .. " selected"
		end
		label.Text = text
		if drawChips then
			drawChips(list)
		end
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

	if chipArea then
		local chipScope
		function drawChips(list)
			if chipScope then
				scope:release(chipScope)
			end
			chipScope = scope:child()
			chipArea.Visible = #list > 0
			for index, value in list do
				local pill = Create.new("Frame", {
					Name = "Chip",
					Size = UDim2.fromOffset(0, 24),
					AutomaticSize = Enum.AutomaticSize.X,
					LayoutOrder = index,
					BackgroundTransparency = 0.85,
					Theme = { BackgroundColor3 = "accent" },
					Parent = chipArea,
				})
				chipScope:add(pill)
				Create.corner(-1, pill)
				Create.padding(pill, 10, 0, 4, 0)
				Create.list(pill, "Horizontal", 4)
				Create.new("TextLabel", {
					Size = UDim2.fromScale(0, 1),
					AutomaticSize = Enum.AutomaticSize.X,
					Text = textOf(value),
					TextSize = 12,
					Weight = "medium",
					Theme = { TextColor3 = "accent" },
					Parent = pill,
				})
				local remove = Create.new("ImageButton", { Name = "Remove", Size = UDim2.fromOffset(18, 18), LayoutOrder = 1, Parent = pill })
				local glyph = Create.icon("x", 12, "accent", remove)
				glyph.AnchorPoint = Vector2.new(0.5, 0.5)
				glyph.Position = UDim2.fromScale(0.5, 0.5)
				chipScope:connect(remove.Activated, function()
					local chosen = selection()
					local found = table.find(chosen, value)
					if found then
						table.remove(chosen, found)
						handle:Set(chosen)
					end
				end)
			end
		end
	end

	-- Builds the option list into `parent`. `close` runs after a single pick.
	local function buildList(parent, session, close)
		local height = if library.touch then 40 else 32
		local items = {}

		local search
		if options.Searchable or (options.Searchable == nil and #values > SEARCHABLE_FROM) then
			search = Create.new("TextBox", {
				Name = "Search",
				Size = UDim2.new(1, 0, 0, height),
				PlaceholderText = "Search",
				TextSize = 13,
				Theme = { BackgroundColor3 = "raised", TextColor3 = "text" },
				Parent = parent,
			})
			session:add(search)
			Create.corner(6, search)
			Create.padding(search, 10, 0)
		end

		local total = 0
		for _, entry in entries do
			total += if entry.heading then 24 elseif entry.description then height + 14 else height
			total += 2
		end
		local list = Create.new("ScrollingFrame", {
			Name = "Options",
			Size = UDim2.new(1, 0, 0, math.min(total, LIST_HEIGHT)),
			LayoutOrder = 1,
			Parent = parent,
		})
		session:add(list)
		Create.list(list, "Vertical", 2)

		for index, entry in entries do
			if entry.heading then
				local heading = Create.new("TextLabel", {
					Name = "Heading",
					Size = UDim2.new(1, 0, 0, 24),
					LayoutOrder = index,
					Text = string.upper(entry.heading),
					TextSize = 12,
					Weight = "bold",
					Theme = { TextColor3 = "textMuted" },
					Parent = list,
				})
				Create.padding(heading, 10, 6, 10, 0)
				items[index] = { heading = heading, entry = entry }
				continue
			end
			local value = entry.value
			local item = Create.new("TextButton", {
				Name = "Option",
				Size = UDim2.new(1, 0, 0, if entry.description then height + 14 else height),
				LayoutOrder = index,
				BackgroundTransparency = 1,
				Theme = { BackgroundColor3 = "hover" },
				Parent = list,
			})
			Create.corner(6, item)
			local lead = 10
			if entry.icon or entry.image then
				local picture = Create.new("ImageLabel", {
					Name = "Icon",
					Size = UDim2.fromOffset(if entry.image then 22 else 16, if entry.image then 22 else 16),
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 10, 0.5, 0),
					Icon = entry.icon,
					Theme = if entry.icon then { ImageColor3 = "textMuted" } else nil,
					Parent = item,
				})
				if entry.image then
					picture.Image = entry.image
					Create.corner(-1, picture)
				end
				lead = 10 + picture.Size.X.Offset + 8
			end
			local text = Create.new("TextLabel", {
				Size = UDim2.new(1, -(lead + 34), 0, 16),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, lead, 0.5, if entry.description then -8 else 0),
				Text = entry.text,
				TextSize = 13,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Theme = { TextColor3 = if entry.disabled then "textMuted" else "text" },
				Parent = item,
			})
			if entry.description then
				Create.new("TextLabel", {
					Name = "Description",
					Size = UDim2.new(1, -(lead + 34), 0, 14),
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, lead, 0.5, 9),
					Text = tostring(entry.description),
					TextSize = 12,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Theme = { TextColor3 = "textMuted" },
					Parent = item,
				})
			end
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
				glyph = Create.new("Frame", {
					Name = "Dot",
					Size = UDim2.fromOffset(8, 8),
					Theme = { BackgroundColor3 = "accent" },
					Parent = mark,
				})
				Create.corner(-1, glyph)
			end
			glyph.AnchorPoint = Vector2.new(0.5, 0.5)
			glyph.Position = UDim2.fromScale(0.5, 0.5)
			if entry.disabled then
				mark.Visible = false
				item.AutoButtonColor = false
				items[index] = { entry = entry, button = item, disabled = true }
				continue
			end
			local slot = { button = item, text = text, mark = mark, edge = edge, glyph = glyph, value = value, entry = entry, on = false }
			items[index] = slot

			-- A picked option keeps a light accent wash; hovering deepens it.
			session:connect(item.MouseEnter, function()
				Motion.tween(item, "fast", { BackgroundTransparency = if slot.on then 0.8 else 0 })
			end)
			session:connect(item.MouseLeave, function()
				Motion.tween(item, "fast", { BackgroundTransparency = if slot.on then 0.88 else 1 })
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
					close()
				end
			end)
		end

		-- Selected shows as a filled mark, an accent wash and a heavier
		-- weight together, never colour alone.
		function repaint()
			for _, item in items do
				if item.value == nil then
					continue
				end
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
					if item.heading then
						-- Headings hide while searching; they would float over no matches.
						item.heading.Visible = query == ""
					else
						local words = string.lower(item.entry.text .. " " .. tostring(item.entry.description or ""))
						item.button.Visible = query == "" or string.find(words, query, 1, true) ~= nil
					end
				end
			end)
		end
	end

	local function closeInline()
		if inlineList then
			scope:release(inlineList.scope)
			inlineList.holder.Visible = false
			inlineList = nil
			repaint = nil
			Motion.tween(chevron, "fast", { Rotation = 0 })
		end
	end

	-- Replaces the choices. Anything picked that is no longer offered is dropped.
	function handle:Refresh(newValues)
		local kept = selection()
		entries, values = entriesFrom(newValues)
		Popup.close(library)
		closeInline()
		store(if multi then kept else kept[1])
	end

	local inlineHolder
	scope:connect(row.frame.Activated, function()
		if look.inline then
			if inlineList then
				closeInline()
				return
			end
			inlineHolder = inlineHolder or row.belowTitle()
			inlineHolder.Visible = true
			Create.list(inlineHolder, "Vertical", 4)
			local session = scope:child()
			inlineList = { scope = session, holder = inlineHolder }
			Motion.tween(chevron, "fast", { Rotation = 180 })
			buildList(inlineHolder, session, closeInline)
			session:add(inlineHolder:FindFirstChildOfClass("UIListLayout"))
			return
		end
		local popup = Popup.toggle(library, chip, {
			Width = math.max(chip.AbsoluteSize.X / library.scale, 190),
			OnClose = function()
				repaint = nil
				Motion.tween(chevron, "fast", { Rotation = 0 })
			end,
		})
		if not popup then
			return
		end
		Motion.tween(chevron, "fast", { Rotation = 180 })
		buildList(popup.frame, popup.scope, popup.close)
	end)

	if options.Players then
		-- The list follows players joining and leaving.
		local function follow()
			handle:Refresh(playerOptions(options.ExcludeSelf))
		end
		scope:connect(Players.PlayerAdded, follow)
		scope:connect(Players.PlayerRemoving, function()
			task.defer(follow)
		end)
	end

	local default = options.Default
	if default == nil and not multi and not options.AllowNone and options.Placeholder == nil then
		default = values[1]
	end
	store(default)
	return handle
end

return Dropdown
