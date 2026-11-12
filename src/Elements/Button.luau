local Create = require("../Core/Create")
local Effects = require("../Core/Effects")
local Motion = require("../Core/Motion")
local Row = require("./Row")
local Theme = require("../Core/Theme")

local VARIANTS = {
	Filled = { fill = "accent", hover = "accentHover", text = "onAccent" },
	Outline = { fill = "raised", hover = "hover", text = "text" },
	Danger = { fill = "danger", hover = "danger", text = "onAccent" },
}

local Button = {}

function Button.new(container, options)
	local roles = VARIANTS[options.Variant]
	if not roles then
		-- The default: the whole row is the button, with a mark on the right.
		local row = Row.new(container, options, { button = true })
		local mark = Create.icon(options.TrailingIcon or "chevron-right", 16, "textMuted", row.slot)
		row.onHover(function(active)
			Theme.bind(mark, "ImageColor3", if active then "accent" else "textMuted")
		end)
		row.scope:connect(row.frame.Activated, row.fire)
		function row.handle:Press()
			row.fire()
		end
		return row.handle
	end

	local row = Row.new(container, options, { bare = true })
	local handle = row.handle
	local button = Create.new("TextButton", {
		Name = "Button",
		Size = UDim2.new(1, 0, 0, 36),
		Text = options.Title,
		Weight = "medium",
		Theme = { BackgroundColor3 = roles.fill, TextColor3 = roles.text },
		Parent = row.content,
	})
	Create.corner(8, button)
	if options.Variant == "Outline" then
		Create.stroke("stroke", button)
	end

	local function paint(role)
		Theme.bind(button, "BackgroundColor3", role, true)
		Motion.tween(button, "fast", { BackgroundColor3 = Theme.color(role) })
	end
	row.scope:connect(button.MouseEnter, function()
		paint(roles.hover)
	end)
	row.scope:connect(button.MouseLeave, function()
		paint(roles.fill)
	end)
	row.scope:connect(button.Activated, row.fire)
	Effects.apply(row.scope, button, options.Effect or row.window.styles.ButtonEffect or row.window.buttonEffect, 8)

	function handle:SetTitle(text)
		self.Title = text
		button.Text = text
		self.SearchText = string.lower(text)
	end

	function handle:Press()
		row.fire()
	end

	return handle
end

return Button
