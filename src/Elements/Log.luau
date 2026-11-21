local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Row = require("./Row")
local Strings = require("../Core/Strings")
local Theme = require("../Core/Theme")

local Log = {}

local MONOSPACE = Font.new("rbxasset://fonts/families/RobotoMono.json")
local LEVELS = { info = "textMuted", success = "success", warn = "warning", error = "danger" }
local FILTERS = { "All", "Info", "Warn", "Error" }

-- A panel of lines the script writes as it works: what it bought, what
-- failed, where it is. Options: Height (default 180), MaxLines (default
-- 200), Timestamps (default true). Add(text, level) writes a line; Info,
-- Success, Warn and Error are shorthands; Clear empties it; Get returns
-- the lines as text.
function Log.new(container, options)
	local row = Row.new(container, options)
	local handle, scope = row.handle, row.scope
	local keep = math.clamp(math.floor(tonumber(options.MaxLines) or 200), 10, 2000)
	local stamps = options.Timestamps ~= false
	local lines = {}
	local filter = "All"
	local order = 0

	local function tool(icon, label, orderIndex)
		local button = Create.new("TextButton", {
			Name = label,
			Size = UDim2.fromOffset(row.reach, row.reach),
			LayoutOrder = orderIndex,
			Theme = { BackgroundColor3 = row.controlRole },
			Parent = row.slot,
		})
		Create.corner(8, button)
		local glyph = Create.icon(icon, 14, "textMuted", button)
		glyph.AnchorPoint, glyph.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		row.onHover(function(on)
			Theme.bind(glyph, "ImageColor3", if on then "text" else "textMuted")
		end, button)
		return button, glyph
	end
	local copyButton, copyGlyph = tool("copy", "Copy", 1)
	local clearButton = tool("trash-2", "Clear", 2)

	local below = row.belowTitle()
	Create.list(below, "Vertical", 6)
	-- Wraps, so longer words in another language move to a second line
	-- instead of running past the row.
	local chips = Create.new("Frame", { Name = "Levels", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = below })
	Create.list(chips, "Horizontal", 4, { Wraps = true })
	local chipButtons = {}
	local box = Create.new("ScrollingFrame", {
		Name = "Lines",
		Size = UDim2.new(1, 0, 0, math.clamp(tonumber(options.Height) or 180, 80, 480)),
		LayoutOrder = 1,
		ScrollBarThickness = 3,
		Theme = { BackgroundColor3 = row.controlRole },
		Parent = below,
	})
	Create.corner(8, box)
	local inner = Create.new("Frame", { Name = "Inner", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = box })
	Create.padding(inner, 10, 8)
	Create.list(inner, "Vertical", 2)
	local empty = Create.new("TextLabel", {
		Name = "Empty",
		Size = UDim2.new(1, 0, 0, 20),
		Text = options.EmptyText or Strings.get("Nothing yet"),
		TextSize = 12,
		LayoutOrder = 0,
		Theme = { TextColor3 = "textMuted" },
		Parent = inner,
	})

	local function shows(line)
		return filter == "All" or string.lower(filter) == line.level or (filter == "Error" and line.level == "error")
	end

	local function paintChips()
		for name, chip in chipButtons do
			local on = name == filter
			Theme.bind(chip, "BackgroundColor3", if on then "accent" else row.controlRole)
			Theme.bind(chip, "TextColor3", if on then "onAccent" else "textMuted")
		end
	end

	local function refresh()
		local visible = 0
		for _, line in lines do
			line.label.Visible = shows(line)
			if line.label.Visible then
				visible += 1
			end
		end
		empty.Visible = visible == 0
	end

	for index, name in FILTERS do
		local chip = Create.new("TextButton", {
			Name = name,
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = Strings.get(name),
			TextSize = 12,
			Weight = "medium",
			LayoutOrder = index,
			Theme = { BackgroundColor3 = row.controlRole, TextColor3 = "textMuted" },
			Parent = chips,
		})
		Create.corner(-1, chip)
		Create.padding(chip, 10, 0)
		chipButtons[name] = chip
		scope:connect(chip.Activated, function()
			filter = name
			paintChips()
			refresh()
		end)
	end
	paintChips()

	-- Follows new lines only while the player is already at the bottom.
	local function atBottom()
		local canvas, shown = box.AbsoluteCanvasSize, box.AbsoluteWindowSize
		if not canvas or not shown then
			return true
		end
		return box.CanvasPosition.Y >= canvas.Y - shown.Y - 24
	end

	function handle:Add(text, level)
		level = if LEVELS[level] then level else "info"
		local follow = atBottom()
		order += 1
		local stamp = if stamps then os.date("%H:%M:%S") .. "  " else ""
		local label = Create.new("TextLabel", {
			Name = "Line",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 12,
			FontFace = MONOSPACE,
			LayoutOrder = order,
			Text = stamp .. tostring(text),
			Theme = { TextColor3 = LEVELS[level] },
			Parent = inner,
		})
		local line = { label = label, level = level, text = stamp .. tostring(text) }
		table.insert(lines, line)
		while #lines > keep do
			table.remove(lines, 1).label:Destroy()
		end
		refresh()
		if follow then
			task.defer(function()
				local canvas, shown = box.AbsoluteCanvasSize, box.AbsoluteWindowSize
				if not scope.cleaned and canvas and shown then
					box.CanvasPosition = Vector2.new(0, math.max(canvas.Y - shown.Y, 0))
				end
			end)
		end
		row.fire(text, level)
	end
	function handle:Info(text)
		handle:Add(text, "info")
	end
	function handle:Success(text)
		handle:Add(text, "success")
	end
	function handle:Warn(text)
		handle:Add(text, "warn")
	end
	function handle:Error(text)
		handle:Add(text, "error")
	end

	function handle:Clear()
		for _, line in lines do
			line.label:Destroy()
		end
		table.clear(lines)
		refresh()
	end

	function handle:Get()
		local out = {}
		for _, line in lines do
			table.insert(out, line.text)
		end
		return table.concat(out, "\n")
	end

	scope:connect(clearButton.Activated, function()
		handle:Clear()
	end)
	scope:connect(copyButton.Activated, function()
		if Env.copy(handle:Get()) then
			Theme.bind(copyGlyph, "ImageColor3", "success")
			task.delay(1.2, function()
				if not scope.cleaned then
					Theme.bind(copyGlyph, "ImageColor3", "textMuted")
				end
			end)
		end
	end)

	refresh()
	return handle
end

return Log
