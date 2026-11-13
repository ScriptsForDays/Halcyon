-- A small menu of actions in the popup layer: MenuButton opens one under
-- its button, and a row's Menu option opens one where it was right-clicked
-- or long-pressed. Items are { Title, Icon, Callback, Danger, Disabled },
-- or { Divider = true } for a line between groups.

local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Motion = require("../Core/Motion")
local Mount = require("../Core/Mount")
local Popup = require("./Popup")
local Theme = require("../Core/Theme")

local Menu = {}

local function item(library, popup, settings, order)
	if settings.Divider then
		local line = Create.new("Frame", { Name = "Divider", Size = UDim2.new(1, -8, 0, 1), LayoutOrder = order, Theme = { BackgroundColor3 = "stroke" }, Parent = popup.frame })
		return line
	end
	local role = if settings.Danger then "danger" else "text"
	local button = Create.new("TextButton", {
		Name = "Item",
		Size = UDim2.new(1, 0, 0, if library.touch then 40 else 30),
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Theme = { BackgroundColor3 = "hover" },
		Parent = popup.frame,
	})
	Create.corner(6, button)
	Create.padding(button, 10, 0)
	Create.list(button, "Horizontal", 10, { VerticalAlignment = Enum.VerticalAlignment.Center })
	if settings.Icon then
		Create.icon(settings.Icon, 15, if settings.Danger then "danger" else "textMuted", button)
	end
	Create.new("TextLabel", {
		Name = "Title",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = settings.Title or "",
		TextSize = 13,
		LayoutOrder = 1,
		Theme = { TextColor3 = role },
		Parent = button,
	})
	if settings.Disabled then
		button.AutoButtonColor = false
		for _, child in button:GetChildren() do
			if child:IsA("TextLabel") then
				child.TextTransparency = 0.5
			elseif child:IsA("ImageLabel") then
				child.ImageTransparency = 0.5
			end
		end
		return button
	end
	popup.scope:connect(button.MouseEnter, function()
		Motion.tween(button, "fast", { BackgroundTransparency = 0 })
	end)
	popup.scope:connect(button.MouseLeave, function()
		Motion.tween(button, "fast", { BackgroundTransparency = 1 })
	end)
	popup.scope:connect(button.Activated, function()
		popup.close()
		Env.call(settings.Title or "Menu", settings.Callback)
	end)
	return button
end

-- Opens the menu under `anchor`, or closes it when it is already open there.
function Menu.open(library, anchor, items, width)
	local popup = Popup.toggle(library, anchor, { Width = width or 200 })
	if not popup then
		return nil
	end
	for order, settings in items do
		if type(settings) == "table" then
			item(library, popup, settings, order)
		end
	end
	return popup
end

-- Opens the menu at a point on screen (where a row was right-clicked),
-- through a one-pixel anchor that leaves with the menu.
function Menu.openAt(library, position, items, width)
	local overlay = Mount.overlay(library)
	local origin = overlay.gui.AbsolutePosition
	local anchor = Create.new("Frame", {
		Name = "MenuAnchor",
		Size = UDim2.fromOffset(1, 1),
		Position = UDim2.fromOffset(position.X - origin.X, position.Y - origin.Y),
		Parent = overlay.popups,
	})
	local popup = Menu.open(library, anchor, items, width)
	if popup then
		popup.scope:add(anchor)
	else
		anchor:Destroy()
	end
	return popup
end

-- Gives `frame` a menu on right-click, and on a long press for touch.
function Menu.attach(scope, library, frame, items)
	local UserInputService = game:GetService("UserInputService")
	local function show()
		local listed = if type(items) == "function" then items() else items
		Menu.openAt(library, UserInputService:GetMouseLocation(), listed)
	end
	scope:connect(frame.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			show()
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local start = input.Position
			local held = true
			local ended
			ended = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End or (input.Position - start).Magnitude > 12 then
					held = false
					ended:Disconnect()
				end
			end)
			task.delay(0.5, function()
				if held and not scope.cleaned then
					ended:Disconnect()
					Menu.openAt(library, Vector2.new(start.X, start.Y), if type(items) == "function" then items() else items)
				end
			end)
		end
	end)
end

-- Lets Theme hold a reference without a cycle in requires.
Menu.Theme = Theme

return Menu
