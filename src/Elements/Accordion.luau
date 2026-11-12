local Create = require("../Core/Create")
local Motion = require("../Core/Motion")
local Row = require("./Row")
local Theme = require("../Core/Theme")

local Accordion = {}

-- A title that opens to show longer text under it: a how-to, a FAQ entry,
-- patch notes. Options: Title, Content, Icon, Open (starts open).
function Accordion.new(container, options)
	local row = Row.new(container, { Title = options.Title, Icon = options.Icon }, { button = true })
	local handle, scope = row.handle, row.scope
	local open = options.Open == true

	local holder = Create.new("Frame", { Name = "Arrow", Size = UDim2.fromOffset(16, 16), Parent = row.slot })
	local chevron = Create.icon("chevron-down", 16, "textMuted", holder)
	local body = row.belowTitle()
	local text = Create.new("TextLabel", {
		Name = "Content",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		RichText = true,
		TextSize = 13,
		Text = tostring(options.Content or ""),
		Theme = { TextColor3 = "textMuted" },
		Parent = body,
	})

	local function draw(timing)
		body.Visible = open
		Motion.tween(chevron, timing, { Rotation = if open then 180 else 0 })
	end

	function handle:Get()
		return open
	end

	function handle:SetOpen(wanted)
		open = wanted == true
		draw("fast")
		self.Changed:Fire(open)
	end

	function handle:Set(content)
		text.Text = tostring(content)
		self.SearchExtra = text.Text
		self.SearchText = string.lower(self.Title .. " " .. text.Text)
	end

	scope:connect(row.frame.Activated, function()
		handle:SetOpen(not open)
	end)
	row.onHover(function(active)
		Theme.bind(chevron, "ImageColor3", if active then "text" else "textMuted")
	end)

	draw(nil)
	handle.SearchExtra = text.Text
	handle.SearchText = string.lower(handle.Title .. " " .. text.Text)
	return handle
end

return Accordion
