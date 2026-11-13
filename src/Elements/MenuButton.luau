local Create = require("../Core/Create")
local Menu = require("../Components/Menu")
local Motion = require("../Core/Motion")
local Row = require("./Row")
local Theme = require("../Core/Theme")

local MenuButton = {}

-- A button that opens a short menu of actions. Options: Text (the button's
-- word, default "Actions"), Icon, Items = { { Title, Icon, Callback, Danger,
-- Disabled } or { Divider = true } }, Width (of the menu).
function MenuButton.new(container, options)
	local row = Row.new(container, options)
	local handle, scope = row.handle, row.scope
	local items = options.Items or {}

	local button = Create.new("TextButton", {
		Name = "Menu",
		Size = UDim2.fromOffset(0, row.reach),
		AutomaticSize = Enum.AutomaticSize.X,
		Theme = { BackgroundColor3 = row.controlRole },
		Parent = row.slot,
	})
	Create.corner(8, button)
	Create.stroke("stroke", button)
	Create.padding(button, 12, 0, 10, 0)
	Create.list(button, "Horizontal", 6, { VerticalAlignment = Enum.VerticalAlignment.Center })
	Create.new("TextLabel", {
		Name = "Label",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = options.Text or "Actions",
		TextSize = 13,
		Weight = "medium",
		Theme = { TextColor3 = "text" },
		Parent = button,
	})
	local chevron = Create.icon("chevron-down", 14, "textMuted", button)
	chevron.LayoutOrder = 1

	row.onHover(function(on)
		Theme.bind(button, "BackgroundColor3", if on then "hover" else row.controlRole)
	end, button)
	scope:connect(button.Activated, function()
		local popup = Menu.open(row.library, button, items, options.Width)
		Motion.tween(chevron, "fast", { Rotation = if popup then 180 else 0 })
		if popup then
			popup.scope:add(function()
				if not scope.cleaned then
					Motion.tween(chevron, "fast", { Rotation = 0 })
				end
			end)
		end
	end)

	-- Replaces the menu's items.
	function handle:SetItems(list)
		items = list or {}
	end

	return handle
end

return MenuButton
