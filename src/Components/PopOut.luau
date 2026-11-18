-- A section's rows in a panel of their own: drag it by its title bar,
-- resize it from the bottom-right corner, and it stays on screen while the
-- hub is hidden, so live readouts and quick switches keep working over the
-- game. Docking puts the rows back where they were. Where each panel sits
-- and whether it was out are saved per hub.

local Create = require("../Core/Create")
local Drag = require("../Core/Drag")
local Mount = require("../Core/Mount")
local Resize = require("../Core/Resize")
local Strings = require("../Core/Strings")
local Theme = require("../Core/Theme")

local PopOut = {}

local MIN_SIZE = Vector2.new(240, 140)
local DEFAULT_SIZE = Vector2.new(320, 300)
local BAR = 36

-- The layer under popups, so a dropdown opened from a panel shows above it.
local function layer(library)
	local overlay = Mount.overlay(library)
	if not overlay.popOuts then
		overlay.popOuts = Create.new("Frame", { Name = "PopOuts", Size = UDim2.fromScale(1, 1), ZIndex = 0, Parent = overlay.gui })
	end
	return overlay.popOuts
end

function PopOut.key(section)
	return `{if section.tab then section.tab.Title else ""}/{section.Title or ""}`
end

function PopOut.open(section)
	if section.popped then
		return
	end
	local window, library = section.window, section.library
	local saved = window.popOutState[PopOut.key(section)] or {}
	local scope = section.scope:child()
	local view = Mount.overlay(library).gui.AbsoluteSize
	local size = Vector2.new(tonumber(saved.w) or DEFAULT_SIZE.X, tonumber(saved.h) or DEFAULT_SIZE.Y)
	local corner = if saved.x and saved.y then Vector2.new(saved.x, saved.y) else Vector2.new(view.X - size.X * window.scale - 24, (view.Y - size.Y * window.scale) / 2)

	local panel = Create.new("Frame", {
		Name = "PopOut",
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(math.round(corner.X), math.round(corner.Y)),
		Theme = { BackgroundColor3 = "surface" },
		Parent = layer(library),
	})
	scope:add(panel)
	Create.corner(12, panel)
	Create.stroke("stroke", panel)
	Create.new("UIScale", { Scale = window.scale, Parent = panel })

	local bar = Create.new("Frame", { Name = "TitleBar", Size = UDim2.new(1, 0, 0, BAR), Parent = panel })
	Create.padding(bar, 12, 0, 6, 0)
	Create.list(bar, "Horizontal", 8, { VerticalAlignment = Enum.VerticalAlignment.Center })
	if section.options.Icon then
		Create.icon(section.options.Icon, 14, "textMuted", bar)
	end
	Create.new("TextLabel", {
		Name = "Title",
		Size = UDim2.fromScale(0, 1),
		TextSize = 13,
		Weight = "bold",
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 1,
		Text = section.Title or "",
		Theme = { TextColor3 = "text" },
		Parent = bar,
	}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	local dock = Create.new("TextButton", { Name = "Dock", Size = UDim2.fromOffset(26, 26), LayoutOrder = 2, Parent = bar })
	Create.corner(6, dock)
	local dockIcon = Create.icon("minimize-2", 14, "textMuted", dock)
	dockIcon.AnchorPoint, dockIcon.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	scope:connect(dock.MouseEnter, function()
		Theme.bind(dockIcon, "ImageColor3", "text")
	end)
	scope:connect(dock.MouseLeave, function()
		Theme.bind(dockIcon, "ImageColor3", "textMuted")
	end)
	scope:connect(dock.Activated, function()
		PopOut.close(section)
	end)
	Create.new("Frame", {
		Name = "Seam",
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, BAR),
		Theme = { BackgroundColor3 = "stroke" },
		Parent = panel,
	})

	local content = Create.new("ScrollingFrame", {
		Name = "Content",
		Size = UDim2.new(1, 0, 1, -BAR - 1),
		Position = UDim2.fromOffset(0, BAR + 1),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Theme = { ScrollBarImageColor3 = "textMuted" },
		Parent = panel,
	})
	Create.padding(content, 4, 4, 6, 8)

	-- The rows move; the section keeps its header and shows where they went.
	local body = section.body
	section.homeOfBody = body.Parent
	body.Parent = content
	local placeholder = Create.new("Frame", {
		Name = "PoppedOut",
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 1,
		Parent = section.root,
	})
	scope:add(placeholder)
	Create.padding(placeholder, 14, 0)
	Create.list(placeholder, "Horizontal", 10, { VerticalAlignment = Enum.VerticalAlignment.Center })
	Create.new("TextLabel", {
		Name = "Note",
		Size = UDim2.fromScale(0, 1),
		TextSize = 12,
		Text = Strings.get("Open in its own window"),
		Theme = { TextColor3 = "textMuted" },
		Parent = placeholder,
	}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	local back = Create.new("TextButton", {
		Name = "BringBack",
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = Strings.get("Bring back"),
		TextSize = 12,
		Weight = "medium",
		LayoutOrder = 1,
		Theme = { BackgroundColor3 = "raised", TextColor3 = "text" },
		Parent = placeholder,
	})
	Create.corner(6, back)
	Create.padding(back, 10, 0)
	scope:connect(back.Activated, function()
		PopOut.close(section)
	end)

	local function remember()
		local position = panel.Position
		window.popOutState[PopOut.key(section)] = {
			open = section.popped == true,
			x = position.X.Offset,
			y = position.Y.Offset,
			w = panel.Size.X.Offset,
			h = panel.Size.Y.Offset,
		}
		window:savePreferences()
	end

	Drag.move(scope, bar, panel, { onMoved = remember })

	-- The corner grip: the top-left corner stays put and the bottom-right
	-- follows the pointer, as with the main window.
	local grip = Create.new("TextButton", {
		Name = "Resize",
		Text = "",
		Size = UDim2.fromOffset(18, 18),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -2, 1, -2),
		ZIndex = 10,
		Parent = panel,
	})
	for _, offset in { Vector2.new(12, 12), Vector2.new(7, 12), Vector2.new(12, 7) } do
		Create.new("Frame", {
			Size = UDim2.fromOffset(2, 2),
			Position = UDim2.fromOffset(offset.X, offset.Y),
			ZIndex = 10,
			Theme = { BackgroundColor3 = "textMuted" },
			Parent = grip,
		})
	end
	Resize.grip(scope, grip, function()
		local room = Mount.overlay(library).gui.AbsoluteSize - Vector2.new(panel.Position.X.Offset, panel.Position.Y.Offset) - Vector2.new(8, 8)
		return {
			size = Vector2.new(panel.Size.X.Offset, panel.Size.Y.Offset),
			scale = window.scale,
			min = MIN_SIZE,
			max = room / window.scale,
		}
	end, function(newSize)
		panel.Size = UDim2.fromOffset(newSize.X, newSize.Y)
	end, remember)

	section.popped = true
	section.popScope = scope
	section.panel = panel
	if section.popButton then
		Theme.bind(section.popButton, "ImageColor3", "accent")
	end
	remember()
	window.SectionPopped:Fire(section, true)
end

function PopOut.close(section)
	if not section.popped then
		return
	end
	local window = section.window
	section.popped = false
	section.body.Parent = section.homeOfBody or section.root
	section.panel = nil
	if section.popButton then
		Theme.bind(section.popButton, "ImageColor3", "textMuted")
	end
	local state = window.popOutState[PopOut.key(section)]
	if state then
		state.open = false
		window:savePreferences()
	end
	section.scope:release(section.popScope)
	section.popScope = nil
	window.SectionPopped:Fire(section, false)
end

-- The header button, for sections made with PopOut = true. A section that
-- was out when the hub last closed comes out again.
function PopOut.attach(section)
	local header = section.header
	if not header then
		return
	end
	local holder = Create.new("TextButton", { Name = "PopOutButton", Size = UDim2.fromOffset(22, 22), LayoutOrder = 3, Parent = header })
	Create.corner(6, holder)
	local icon = Create.icon("external-link", 14, "textMuted", holder)
	icon.AnchorPoint, icon.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	section.popButton = icon
	section.scope:connect(holder.Activated, function()
		if section.popped then
			PopOut.close(section)
		else
			PopOut.open(section)
		end
	end)
	local saved = section.window.popOutState[PopOut.key(section)]
	if saved and saved.open then
		task.defer(function()
			if not section.scope.cleaned then
				PopOut.open(section)
			end
		end)
	end
end

return PopOut
