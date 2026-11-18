-- Saved places the player can go back to: stand somewhere, name it, save
-- it, and teleport there later. With a Flag the list is kept in configs.
--
-- Options: Teleport(cframe, name) (how to get there; without it the local
-- character is moved, which works for the player's own character),
-- GetPosition() (where "Save here" reads from; the character's root part
-- by default), Max [50], Height [220, then it scrolls].
-- Value: { { Name, CFrame } } in the player's order.

local Players = game:GetService("Players")

local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Row = require("./Row")
local Strings = require("../Core/Strings")
local Theme = require("../Core/Theme")

local Waypoints = {}

local function characterPosition()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root then root.CFrame else nil
end

local function components(cframe)
	return { cframe:GetComponents() }
end

function Waypoints.new(container, options)
	local row = Row.new(container, options)
	local handle, scope = row.handle, row.scope
	local list = {}
	local max = tonumber(options.Max) or 50

	local area = row.belowTitle()
	Create.list(area, "Vertical", 6)
	local top = Create.new("Frame", { Name = "Add", Size = UDim2.new(1, 0, 0, row.reach), Parent = area })
	Create.list(top, "Horizontal", 8, { VerticalAlignment = Enum.VerticalAlignment.Center })
	local nameBox = Create.new("TextBox", {
		Name = "PlaceName",
		Size = UDim2.new(1, -120, 1, 0),
		PlaceholderText = Strings.get("Name this place"),
		Text = "",
		TextSize = 13,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Theme = { BackgroundColor3 = row.controlRole, TextColor3 = "text", PlaceholderColor3 = "textMuted" },
		Parent = top,
	}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	Create.corner(8, nameBox)
	Create.padding(nameBox, 10, 0)
	Create.stroke("stroke", nameBox)
	local saveButton = Create.new("TextButton", {
		Name = "SaveHere",
		Size = UDim2.fromOffset(0, row.reach),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = Strings.get("Save here"),
		TextSize = 13,
		Weight = "medium",
		LayoutOrder = 1,
		Theme = { BackgroundColor3 = "accent", TextColor3 = "onAccent" },
		Parent = top,
	})
	Create.corner(8, saveButton)
	Create.padding(saveButton, 12, 0)

	local scroller = Create.new("ScrollingFrame", {
		Name = "Places",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		LayoutOrder = 1,
		Theme = { ScrollBarImageColor3 = "textMuted" },
		Parent = area,
	})
	local layout = Create.list(scroller, "Vertical", 4)
	local empty = Create.new("TextLabel", {
		Name = "Empty",
		Size = UDim2.new(1, 0, 0, 28),
		Text = Strings.get("No places saved yet"),
		TextSize = 12,
		LayoutOrder = 2,
		Theme = { TextColor3 = "textMuted" },
		Parent = area,
	})
	local maxHeight = tonumber(options.Height) or 220
	scope:connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		scroller.Size = UDim2.new(1, 0, 0, math.min(layout.AbsoluteContentSize.Y / row.library.scale, maxHeight))
	end)

	local function teleport(entry)
		if handle:IsLocked() then
			return
		end
		if type(options.Teleport) == "function" then
			Env.call(handle.Title, options.Teleport, entry.CFrame, entry.Name)
			return
		end
		local character = Players.LocalPlayer.Character
		if character then
			pcall(character.PivotTo, character, entry.CFrame)
		end
	end

	local draw
	local function changed()
		draw()
		row.fire(handle:Get())
	end

	local function iconButton(parent, icon, order, role)
		local button = Create.new("TextButton", {
			Name = icon,
			Size = UDim2.fromOffset(row.reach - 4, row.reach - 4),
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Theme = { BackgroundColor3 = "hover" },
			Parent = parent,
		})
		Create.corner(6, button)
		local glyph = Create.icon(icon, 15, role or "textMuted", button)
		glyph.AnchorPoint, glyph.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		scope:connect(button.MouseEnter, function()
			button.BackgroundTransparency = 0
		end)
		scope:connect(button.MouseLeave, function()
			button.BackgroundTransparency = 1
		end)
		return button
	end

	local lines = {}
	function draw()
		for _, line in lines do
			line:Destroy()
		end
		table.clear(lines)
		empty.Visible = #list == 0
		for index, entry in list do
			local line = Create.new("Frame", {
				Name = "Place",
				Size = UDim2.new(1, -6, 0, row.reach),
				LayoutOrder = index,
				Theme = { BackgroundColor3 = row.controlRole },
				Parent = scroller,
			})
			table.insert(lines, line)
			Create.corner(8, line)
			Create.padding(line, 10, 0, 4, 0)
			Create.list(line, "Horizontal", 2, { VerticalAlignment = Enum.VerticalAlignment.Center })
			local pin = Create.icon("map-pin", 14, "accent", line)
			pin.LayoutOrder = 0
			-- The name edits in place; an empty name keeps the old one.
			local label = Create.new("TextBox", {
				Name = "Name",
				Size = UDim2.new(0, 0, 1, 0),
				Text = entry.Name,
				TextSize = 13,
				ClearTextOnFocus = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = 1,
				Theme = { TextColor3 = "text" },
				Parent = line,
			}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
			Create.padding(label, 6, 0)
			scope:connect(label.FocusLost, function()
				local typed = string.match(label.Text, "^%s*(.-)%s*$")
				if typed ~= "" and typed ~= entry.Name then
					entry.Name = typed
					changed()
				else
					label.Text = entry.Name
				end
			end)
			local go = iconButton(line, "arrow-right", 2, "accent")
			scope:connect(go.Activated, function()
				teleport(entry)
			end)
			if index > 1 then
				scope:connect(iconButton(line, "chevron-up", 3).Activated, function()
					list[index], list[index - 1] = list[index - 1], list[index]
					changed()
				end)
			end
			if index < #list then
				scope:connect(iconButton(line, "chevron-down", 4).Activated, function()
					list[index], list[index + 1] = list[index + 1], list[index]
					changed()
				end)
			end
			scope:connect(iconButton(line, "trash-2", 5, "danger").Activated, function()
				table.remove(list, index)
				changed()
			end)
		end
	end

	local function save()
		if handle:IsLocked() then
			return
		end
		local read = if type(options.GetPosition) == "function" then options.GetPosition else characterPosition
		local ok, position = pcall(read)
		if not ok or typeof(position) ~= "CFrame" then
			row.window:Notify({ Title = Strings.get("Place not saved"), Content = Strings.get("Your character isn't in the game yet."), Kind = "warning" })
			return
		end
		if #list >= max then
			row.window:Notify({ Title = Strings.get("Place not saved"), Content = Strings.get("Delete a place to make room."), Kind = "warning" })
			return
		end
		local typed = string.match(nameBox.Text, "^%s*(.-)%s*$")
		local name = if typed ~= "" then typed else Strings.get("Place {number}", { number = #list + 1 })
		table.insert(list, { Name = name, CFrame = position })
		nameBox.Text = ""
		changed()
	end
	scope:connect(saveButton.Activated, save)
	scope:connect(nameBox.FocusLost, function(enter)
		if enter then
			save()
		end
	end)
	scope:connect(saveButton.MouseEnter, function()
		Theme.bind(saveButton, "BackgroundColor3", "accentHover")
	end)
	scope:connect(saveButton.MouseLeave, function()
		Theme.bind(saveButton, "BackgroundColor3", "accent")
	end)

	function handle:Get()
		local copy = {}
		for _, entry in list do
			table.insert(copy, { Name = entry.Name, CFrame = entry.CFrame })
		end
		return copy
	end

	function handle:Set(newList)
		list = {}
		for _, entry in (if type(newList) == "table" then newList else {}) do
			if type(entry) == "table" and typeof(entry.CFrame) == "CFrame" then
				table.insert(list, { Name = tostring(entry.Name or ""), CFrame = entry.CFrame })
			end
		end
		changed()
	end

	-- Moves to a saved place by name or position in the list.
	function handle:Teleport(which)
		for index, entry in list do
			if entry.Name == which or index == which then
				teleport(entry)
				return true
			end
		end
		return false
	end

	-- Saved as plain numbers so configs and share codes can carry them.
	function handle:Encode()
		local saved = {}
		for _, entry in list do
			table.insert(saved, { name = entry.Name, at = components(entry.CFrame) })
		end
		return saved
	end

	function handle:Decode(saved)
		local decoded = {}
		for _, entry in (if type(saved) == "table" then saved else {}) do
			if type(entry) == "table" and type(entry.at) == "table" and #entry.at == 12 then
				table.insert(decoded, { Name = tostring(entry.name or ""), CFrame = CFrame.new(table.unpack(entry.at)) })
			end
		end
		return decoded
	end

	-- A starting list shows without running the Callback.
	for _, entry in (if type(options.Default) == "table" then options.Default else {}) do
		if type(entry) == "table" and typeof(entry.CFrame) == "CFrame" then
			table.insert(list, { Name = tostring(entry.Name or ""), CFrame = entry.CFrame })
		end
	end
	draw()
	return handle
end

return Waypoints
