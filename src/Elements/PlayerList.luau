local Players = game:GetService("Players")

local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Row = require("./Row")
local Strings = require("../Core/Strings")
local Theme = require("../Core/Theme")

local PlayerList = {}

-- The players in the server as rows: picture, display name and @name, and
-- the hub's own buttons on each (spectate, teleport, add to a whitelist).
-- It follows players joining and leaving. Options: Actions = { { Title,
-- Icon, Callback(player) } }, Search (default true), ShowSelf (default
-- false), Height (the most it shows before scrolling, default 240),
-- Selectable (pressing a row picks that player; Get returns their name).
function PlayerList.new(container, options)
	local row = Row.new(container, options)
	local handle, scope = row.handle, row.scope
	local localPlayer = Players.LocalPlayer
	local selected
	local rows = {}
	local itemHeight = if row.library.touch then 48 else 42

	local count = Create.new("TextLabel", {
		Name = "Count",
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 12,
		Theme = { TextColor3 = "textMuted" },
		Parent = row.slot,
	})
	local below = row.belowTitle()
	Create.list(below, "Vertical", 6)
	local search
	if options.Search ~= false then
		search = Create.new("TextBox", {
			Name = "Search",
			Size = UDim2.new(1, 0, 0, 30),
			PlaceholderText = Strings.get("Find a player"),
			TextSize = 13,
			ClearTextOnFocus = false,
			Theme = { BackgroundColor3 = row.controlRole, TextColor3 = "text" },
			Parent = below,
		})
		Create.corner(8, search)
		Create.padding(search, 10, 0)
	end
	local box = Create.new("ScrollingFrame", {
		Name = "Players",
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
		ScrollBarThickness = 3,
		Theme = { BackgroundColor3 = row.controlRole },
		Parent = below,
	})
	Create.corner(8, box)
	local inner = Create.new("Frame", { Name = "Inner", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = box })
	Create.padding(inner, 4)
	Create.list(inner, "Vertical", 2)
	Create.fitHeight(box, inner, math.clamp(tonumber(options.Height) or 240, 90, 520), row.library, scope)
	local empty = Create.new("TextLabel", {
		Name = "Empty",
		Size = UDim2.new(1, 0, 0, 36),
		Text = Strings.get("No one else is here"),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		Theme = { TextColor3 = "textMuted" },
		Parent = inner,
	})

	local function paint()
		local query = if search then string.lower(search.Text) else ""
		local shown = 0
		for player, entry in rows do
			local match = query == "" or string.find(string.lower(player.Name), query, 1, true) or string.find(string.lower(player.DisplayName), query, 1, true)
			entry.button.Visible = match ~= nil and match ~= false
			if entry.button.Visible then
				shown += 1
			end
			local on = selected == player
			Theme.bind(entry.button, "BackgroundColor3", if on then "accent" else "hover")
			entry.button.BackgroundTransparency = if on then 0.86 else 1
		end
		empty.Visible = shown == 0
		local total = 0
		for _ in rows do
			total += 1
		end
		count.Text = if total == 1 then Strings.get("1 player") else Strings.get("{count} players", { count = total })
		-- With nobody to list, the empty line below says so on its own.
		count.Visible = total > 0
	end

	local function add(player)
		if rows[player] or (player == localPlayer and not options.ShowSelf) then
			return
		end
		local button = Create.new("TextButton", {
			Name = player.Name,
			Size = UDim2.new(1, 0, 0, itemHeight),
			BackgroundTransparency = 1,
			Theme = { BackgroundColor3 = "hover" },
			Parent = inner,
		})
		Create.corner(6, button)
		Create.padding(button, 8, 0)
		Create.list(button, "Horizontal", 10, { VerticalAlignment = Enum.VerticalAlignment.Center })
		local picture = Create.new("ImageLabel", {
			Name = "Avatar",
			Size = UDim2.fromOffset(itemHeight - 12, itemHeight - 12),
			Image = `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=60&h=60`,
			Theme = { BackgroundColor3 = "raised" },
			Parent = button,
		})
		Create.corner(-1, picture)
		local names = Create.new("Frame", { Name = "Names", Size = UDim2.fromScale(0, 1), LayoutOrder = 1, Parent = button }, {
			Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
		})
		Create.list(names, "Vertical", 0, { VerticalAlignment = Enum.VerticalAlignment.Center })
		Create.new("TextLabel", {
			Name = "Display",
			Size = UDim2.new(1, 0, 0, 16),
			Text = player.DisplayName,
			TextSize = 13,
			Weight = "medium",
			TextTruncate = Enum.TextTruncate.AtEnd,
			Theme = { TextColor3 = "text" },
			Parent = names,
		})
		Create.new("TextLabel", {
			Name = "User",
			Size = UDim2.new(1, 0, 0, 14),
			Text = "@" .. player.Name,
			TextSize = 11,
			LayoutOrder = 1,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Theme = { TextColor3 = "textMuted" },
			Parent = names,
		})
		for order, settings in options.Actions or {} do
			local action = Create.new("TextButton", {
				Name = settings.Title or "Action",
				Size = UDim2.fromOffset(row.reach, row.reach),
				LayoutOrder = 1 + order,
				Theme = { BackgroundColor3 = row.controlRole },
				Parent = button,
			})
			Create.corner(8, action)
			local glyph = Create.icon(settings.Icon or "arrow-right", 14, "textMuted", action)
			glyph.AnchorPoint, glyph.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
			row.onHover(function(on)
				Theme.bind(glyph, "ImageColor3", if on then "accent" else "textMuted")
			end, action)
			scope:connect(action.Activated, function()
				Env.call(settings.Title or "Player action", settings.Callback, player)
			end)
		end
		if options.Selectable then
			scope:connect(button.Activated, function()
				selected = if selected == player then nil else player
				paint()
				row.fire(if selected then selected.Name else nil)
			end)
		end
		rows[player] = { button = button }
		paint()
	end

	local function drop(player)
		local entry = rows[player]
		if entry then
			entry.button:Destroy()
			rows[player] = nil
			if selected == player then
				selected = nil
				row.fire(nil)
			end
			paint()
		end
	end

	for _, player in Players:GetPlayers() do
		add(player)
	end
	scope:connect(Players.PlayerAdded, add)
	scope:connect(Players.PlayerRemoving, drop)
	if search then
		scope:connect(search:GetPropertyChangedSignal("Text"), paint)
	end

	function handle:Get()
		return if selected then selected.Name else nil
	end

	function handle:Set(name)
		selected = if type(name) == "string" then Players:FindFirstChild(name) else nil
		paint()
		row.fire(if selected then selected.Name else nil)
	end

	paint()
	return handle
end

return PlayerList
