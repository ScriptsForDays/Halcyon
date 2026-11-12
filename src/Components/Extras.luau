-- Optional HUD pieces that sit outside the window: a watermark line and a
-- list of active keybinds. Both update from the window's one-second tick or
-- from change events, never per frame.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Create = require("../Core/Create")
local Drag = require("../Core/Drag")
local Env = require("../Core/Env")
local Profile = require("./Profile")
local Theme = require("../Core/Theme")

local Extras = {}

local function handleFor(window, scope, frame)
	local handle = { Frame = frame }
	function handle:SetVisible(visible)
		frame.Visible = visible
	end
	function handle:Destroy()
		window.scope:release(scope)
	end
	return handle
end

-- Options: Fields, a list of "Title", "User", "Executor", "FPS", "Ping",
-- "Time", "Date", any other text, or functions returning text.
function Extras.watermark(window, options)
	options = options or {}
	local scope = window.scope:child()
	local fields = options.Fields or { "Title", "Executor", "Time" }
	local frames, rate = 0, 0

	local pill = Create.new("Frame", {
		Name = "Watermark",
		AutomaticSize = Enum.AutomaticSize.XY,
		Position = options.Position or UDim2.fromOffset(12, 12),
		Active = true,
		Theme = { BackgroundColor3 = "surface" },
		Parent = window.gui,
	})
	scope:add(pill)
	Create.corner(8, pill)
	Create.stroke("stroke", pill)
	Create.padding(pill, 10, 7)
	Create.list(pill, "Horizontal", 8)
	if window.Icon then
		Create.icon(window.Icon, 14, "accent", pill)
	end
	local label = Create.new("TextLabel", { AutomaticSize = Enum.AutomaticSize.XY, TextSize = 12, Weight = "medium", LayoutOrder = 1, Theme = { TextColor3 = "text" }, Parent = pill })

	local function text(field)
		if type(field) == "function" then
			local ok, value = pcall(field)
			return if ok then tostring(value) else ""
		elseif field == "Title" then
			return window.Title
		elseif field == "User" then
			return (Profile.names(window.profile))
		elseif field == "Executor" then
			return (Env.executor())
		elseif field == "Time" then
			return os.date("%H:%M:%S")
		elseif field == "Date" then
			return os.date("%d %b %Y")
		elseif field == "FPS" then
			return rate .. " fps"
		elseif field == "Ping" then
			return math.round(Players.LocalPlayer:GetNetworkPing() * 1000) .. " ms"
		end
		return tostring(field)
	end

	local function draw()
		local parts = {}
		for index, field in fields do
			parts[index] = text(field)
		end
		label.Text = table.concat(parts, "  |  ")
	end

	if table.find(fields, "FPS") then
		-- Counting frames is the only way to know the rate; the handler does
		-- nothing but add one.
		scope:connect(RunService.Heartbeat, function()
			frames += 1
		end)
	end
	window:everySecond(scope, function()
		rate, frames = frames, 0
		draw()
	end)
	Drag.move(scope, pill, pill, {})
	draw()
	return handleFor(window, scope, pill)
end

-- Lists every bound key with the row it belongs to; active ones are marked.
function Extras.keybindList(window, options)
	options = options or {}
	local scope = window.scope:child()
	local panel = Create.new("Frame", {
		Name = "Keybinds",
		Size = UDim2.fromOffset(200, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = options.Position or UDim2.new(0, 12, 0.4, 0),
		Active = true,
		Theme = { BackgroundColor3 = "surface" },
		Parent = window.gui,
	})
	scope:add(panel)
	Create.corner(10, panel)
	Create.stroke("stroke", panel)
	Create.padding(panel, 12, 10)
	Create.list(panel, "Vertical", 6)
	Create.new("TextLabel", { Size = UDim2.new(1, 0, 0, 16), Text = options.Title or "Keybinds", TextSize = 12, Weight = "bold", Theme = { TextColor3 = "textMuted" }, Parent = panel })
	local rows = Create.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = panel })

	local function draw()
		rows:ClearAllChildren()
		Create.list(rows, "Vertical", 4)
		local count = 0
		for _, listing in window.keybinds do
			local key = listing.control:Get()
			if key then
				count += 1
				local active = listing.control.Active
				local row = Create.new("Frame", { Size = UDim2.new(1, 0, 0, 18), LayoutOrder = count, Parent = rows })
				Create.new("TextLabel", {
					Size = UDim2.new(1, -70, 1, 0),
					Text = listing.handle.Title,
					TextSize = 12,
					Weight = if active then "bold" else "regular",
					TextTruncate = Enum.TextTruncate.AtEnd,
					Theme = { TextColor3 = if active then "text" else "textMuted" },
					Parent = row,
				})
				Create.new("TextLabel", {
					Size = UDim2.new(0, 66, 1, 0),
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Text = key.Name,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Right,
					Theme = { TextColor3 = if active then "accent" else "textMuted" },
					Parent = row,
				})
			end
		end
		panel.Visible = count > 0
	end

	scope:add(window.KeybindsChanged:Connect(draw))
	scope:add(Theme.Changed:Connect(draw))
	Drag.move(scope, panel, panel, {})
	draw()
	return handleFor(window, scope, panel)
end

return Extras
