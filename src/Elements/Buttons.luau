local Create = require("../Core/Create")
local Effects = require("../Core/Effects")
local Env = require("../Core/Env")
local Motion = require("../Core/Motion")
local Row = require("./Row")
local Styles = require("../Core/Styles")
local Theme = require("../Core/Theme")

local Buttons = {}

-- Several buttons side by side in one row, sharing its width: Save / Load,
-- Accept / Decline. Options: Buttons = { { Title, Icon, Variant, Callback } },
-- Title (optional, shown above them). Each Variant is a Button look; the
-- "Row" look falls back to Outline.
function Buttons.new(container, options)
	local row = Row.new(container, options, { bare = options.Title == nil })
	local handle, scope = row.handle, row.scope
	local holder = Create.new("Frame", {
		Name = "Buttons",
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 3,
		Parent = row.content,
	})
	Create.list(holder, "Horizontal", 8, { Wraps = false })
	handle.Buttons = {}

	for index, spec in options.Buttons or {} do
		local look = Styles.get("Button", spec.Variant or spec.Style)
		if not look or look.row then
			look = Styles.get("Button", if index == 1 then "Filled" else "Outline")
		end
		local button = Create.new("TextButton", {
			Name = "Button",
			Size = UDim2.fromScale(0, 1),
			LayoutOrder = index,
			BackgroundTransparency = look.fillTransparency or 0,
			Theme = { BackgroundColor3 = look.fill },
			Parent = holder,
		}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
		Create.corner(8, button)
		if look.stroke then
			Create.stroke(look.stroke, button)
		end
		local inner = Create.new("Frame", {
			Name = "Inner",
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			ZIndex = 3,
			Parent = button,
		})
		Create.list(inner, "Horizontal", 6)
		if spec.Icon then
			Create.icon(spec.Icon, 15, look.text, inner)
		end
		Create.new("TextLabel", {
			Name = "Label",
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = tostring(spec.Title or ""),
			Weight = "medium",
			TextSize = 13,
			LayoutOrder = 1,
			Theme = { TextColor3 = look.text },
			Parent = inner,
		})
		local function paint(hovered)
			local role = if hovered then look.hover else look.fill
			Theme.bind(button, "BackgroundColor3", role, true)
			Motion.tween(button, "fast", {
				BackgroundColor3 = Theme.color(role),
				BackgroundTransparency = if hovered then look.hoverTransparency or look.fillTransparency or 0 else look.fillTransparency or 0,
			})
		end
		scope:connect(button.MouseEnter, function()
			paint(true)
		end)
		scope:connect(button.MouseLeave, function()
			paint(false)
		end)
		scope:connect(button.Activated, function()
			handle.Changed:Fire(spec.Title)
			Env.call(tostring(spec.Title), spec.Callback)
		end)
		Effects.apply(scope, button, spec.Effect or row.window.styles.ButtonEffect or row.window.buttonEffect, 8)
		handle.Buttons[index] = button
	end

	local words = {}
	for _, spec in options.Buttons or {} do
		table.insert(words, tostring(spec.Title or ""))
	end
	handle.SearchExtra = table.concat(words, " ")
	handle.SearchText = string.lower((options.Title or "") .. " " .. handle.SearchExtra)
	return handle
end

return Buttons
