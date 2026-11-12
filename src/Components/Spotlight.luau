-- A one-time pointer at something new: a pulsing dot on the row and a
-- callout with a "Got it" button. Once dismissed it is remembered with the
-- window's preferences and never shown again.

local Create = require("../Core/Create")
local Effects = require("../Core/Effects")
local Mount = require("../Core/Mount")
local Motion = require("../Core/Motion")

local GAP, MARGIN = 8, 8

local Spotlight = {}

-- Options: Title, Text, Id (what is remembered; defaults to the row's title).
function Spotlight.attach(window, handle, options)
	options = if type(options) == "table" then options else { Text = tostring(options) }
	local id = tostring(options.Id or handle.Title)
	if window.seenSpotlights[id] then
		return nil
	end
	local library, scope = window.library, handle.scope:child()
	local frame = handle.Frame

	local dot = Create.new("Frame", {
		Name = "Spotlight",
		Size = UDim2.fromOffset(8, 8),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(6, 6),
		ZIndex = 8,
		Theme = { BackgroundColor3 = "accent" },
		Parent = frame,
	})
	Create.corner(-1, dot)
	scope:add(dot)
	local ring = Create.new("UIStroke", { Theme = { Color = "accent" }, Parent = dot })
	Effects.pulse(scope, ring).start()

	local card
	local spot = {}
	function spot.dismiss()
		window.seenSpotlights[id] = true
		window:savePreferences()
		handle.scope:release(scope)
	end

	-- The callout shows while the row's tab is open and the row is on screen.
	local function refresh()
		local visible = window.Visible and handle.Tab ~= nil and window.selected == handle.Tab and frame.Visible ~= false and not handle.Hidden
		-- Only while the row is fully inside the page's visible area; a
		-- callout for a row scrolled away would float over other rows.
		local page = handle.Tab and handle.Tab.page
		if visible and page and page.AbsoluteSize.Y > 0 then
			local top, bottom = page.AbsolutePosition.Y, page.AbsolutePosition.Y + page.AbsoluteSize.Y
			visible = frame.AbsolutePosition.Y >= top and frame.AbsolutePosition.Y + frame.AbsoluteSize.Y <= bottom
		end
		if not visible then
			if card then
				card:Destroy()
				card = nil
			end
			return
		end
		if card then
			return
		end
		local overlay = Mount.overlay(library)
		card = Create.new("Frame", {
			Name = "Callout",
			Size = UDim2.fromOffset(240, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Theme = { BackgroundColor3 = "accent" },
			Parent = overlay.popups,
		})
		scope:add(card)
		Create.new("UIScale", { Scale = library.scale, Parent = card })
		Create.corner(10, card)
		Create.padding(card, 12, 10)
		Create.list(card, "Vertical", 4)
		if options.Title then
			Create.new("TextLabel", {
				Size = UDim2.new(1, 0, 0, 18),
				Text = tostring(options.Title),
				Weight = "bold",
				Theme = { TextColor3 = "onAccent" },
				Parent = card,
			})
		end
		if options.Text then
			Create.new("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true,
				TextSize = 13,
				LayoutOrder = 1,
				Text = tostring(options.Text),
				TextTransparency = 0.1,
				Theme = { TextColor3 = "onAccent" },
				Parent = card,
			})
		end
		local button = Create.new("TextButton", {
			Name = "GotIt",
			Size = UDim2.fromOffset(0, if library.touch then 40 else 28),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = options.Button or "Got it",
			TextSize = 12,
			Weight = "bold",
			LayoutOrder = 2,
			BackgroundTransparency = 0.8,
			Theme = { BackgroundColor3 = "onAccent", TextColor3 = "onAccent" },
			Parent = card,
		})
		Create.corner(6, button)
		Create.padding(button, 12, 0)
		scope:connect(button.Activated, spot.dismiss)
		local function place()
			if not card then
				return
			end
			local view, origin = overlay.gui.AbsoluteSize, overlay.gui.AbsolutePosition
			local corner, size = frame.AbsolutePosition - origin, card.AbsoluteSize
			local y = corner.Y + frame.AbsoluteSize.Y + GAP
			if y + size.Y > view.Y - MARGIN then
				y = corner.Y - size.Y - GAP
			end
			card.Position = UDim2.fromOffset(
				math.round(math.clamp(corner.X + 12, MARGIN, math.max(view.X - size.X - MARGIN, MARGIN))),
				math.round(math.clamp(y, MARGIN, math.max(view.Y - size.Y - MARGIN, MARGIN)))
			)
		end
		scope:connect(card:GetPropertyChangedSignal("AbsoluteSize"), place)
		scope:connect(frame:GetPropertyChangedSignal("AbsolutePosition"), place)
		place()
		if not Motion.reduced then
			card.BackgroundTransparency = 1
			Motion.tween(card, "base", { BackgroundTransparency = 0 })
		end
	end

	scope:add(window.TabChanged:Connect(refresh))
	if handle.Tab then
		scope:connect(handle.Tab.page:GetPropertyChangedSignal("CanvasPosition"), refresh)
	end
	scope:connect(frame:GetPropertyChangedSignal("Visible"), refresh)
	window.visibilityHooks = window.visibilityHooks or {}
	table.insert(window.visibilityHooks, refresh)
	scope:add(function()
		local hooks = window.visibilityHooks
		local index = table.find(hooks, refresh)
		if index then
			table.remove(hooks, index)
		end
	end)
	task.defer(refresh)
	spot.refresh = refresh
	return spot
end

return Spotlight
