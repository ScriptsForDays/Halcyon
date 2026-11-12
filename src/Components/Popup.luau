-- The floating panel that dropdowns, colour pickers and the profile chip
-- open. It lives in the overlay ScreenGui so a ScrollingFrame cannot clip it,
-- and it is always kept on screen. One popup is open at a time.

local UserInputService = game:GetService("UserInputService")

local Create = require("../Core/Create")
local Motion = require("../Core/Motion")
local Mount = require("../Core/Mount")

local MARGIN, GAP = 8, 6

local Popup = {}

local function contains(instance, position)
	local origin, size = instance.AbsolutePosition, instance.AbsoluteSize
	return position.X >= origin.X and position.X <= origin.X + size.X and position.Y >= origin.Y and position.Y <= origin.Y + size.Y
end

function Popup.close(kit)
	if kit.popup then
		kit.popup.close()
	end
end

-- Opens a popup under `anchor`, or closes it when it is already open there.
-- Returns the popup ({ frame, scope, close }) or nil when it closed.
function Popup.toggle(kit, anchor, options)
	local open = kit.popup
	Popup.close(kit)
	if open and open.anchor == anchor then
		return nil
	end

	local overlay = Mount.overlay(kit)
	local scope = kit.scope:child()
	local width = options.Width or math.max(anchor.AbsoluteSize.X / kit.scale, 180)

	-- The holder carries the position and the panel carries the scale, so
	-- scaling never moves the popup away from its anchor.
	local holder = Create.new("Frame", { Name = "Popup", Parent = overlay.popups })
	local panel = Create.new("Frame", {
		Name = "Panel",
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Active = true,
		Theme = { BackgroundColor3 = "surface" },
		Parent = holder,
	})
	Create.corner(10, panel)
	Create.stroke("stroke", panel)
	Create.padding(panel, 6)
	Create.list(panel, "Vertical", 4)
	Create.new("UIScale", { Scale = kit.scale, Parent = panel })
	scope:add(holder)

	local popup = { anchor = anchor, frame = panel, scope = scope }

	local function place()
		local view, origin = overlay.gui.AbsoluteSize, overlay.gui.AbsolutePosition
		local size = panel.AbsoluteSize
		local corner, extent = anchor.AbsolutePosition - origin, anchor.AbsoluteSize
		local x = corner.X + extent.X - size.X
		local y = corner.Y + extent.Y + GAP
		if y + size.Y > view.Y - MARGIN then
			y = corner.Y - size.Y - GAP
		end
		holder.Position = UDim2.fromOffset(
			math.clamp(x, MARGIN, math.max(view.X - size.X - MARGIN, MARGIN)),
			math.clamp(y, MARGIN, math.max(view.Y - size.Y - MARGIN, MARGIN))
		)
	end

	function popup.close()
		if kit.popup ~= popup then
			return
		end
		kit.popup = nil
		kit.scope:release(scope)
		if options.OnClose then
			options.OnClose()
		end
	end

	scope:connect(panel:GetPropertyChangedSignal("AbsoluteSize"), place)
	-- A scroll, a window drag or a tab switch moves the anchor; the popup
	-- closes instead of floating where the control used to be.
	scope:connect(anchor:GetPropertyChangedSignal("AbsolutePosition"), popup.close)
	-- A screen resize closes the popup too. A new overlay only learns its
	-- size a frame after it is created, and that first report is not a resize.
	local view = overlay.gui.AbsoluteSize
	scope:connect(overlay.gui:GetPropertyChangedSignal("AbsoluteSize"), function()
		local size = overlay.gui.AbsoluteSize
		if view.X > 0 and size ~= view then
			popup.close()
		else
			view = size
			place()
		end
	end)
	scope:connect(anchor.Destroying, popup.close)
	scope:connect(UserInputService.InputBegan, function(input)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		-- A press on the anchor is left to its own handler, which toggles.
		if not contains(panel, input.Position) and not contains(anchor, input.Position) then
			popup.close()
		end
	end)

	kit.popup = popup
	place()
	-- The panel drops the last few pixels into place.
	panel.Position = UDim2.fromOffset(0, -6)
	Motion.tween(panel, "base", { Position = UDim2.fromOffset(0, 0) })
	return popup
end

return Popup
