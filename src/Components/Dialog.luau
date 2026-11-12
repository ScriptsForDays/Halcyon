-- A modal card over a scrim. The scrim takes every press, so nothing under
-- the dialog can be clicked until it is answered.

local Create = require("../Core/Create")
local Effects = require("../Core/Effects")
local Env = require("../Core/Env")
local Motion = require("../Core/Motion")
local Mount = require("../Core/Mount")
local Theme = require("../Core/Theme")

local VARIANTS = {
	Primary = { fill = "accent", hover = "accentHover", text = "onAccent" },
	Danger = { fill = "danger", hover = "danger", text = "onAccent" },
	Default = { fill = "raised", hover = "hover", text = "text" },
}

local Dialog = {}

-- A themed button used by dialogs and the key prompt.
function Dialog.button(scope, parent, options)
	local roles = VARIANTS[options.Variant] or VARIANTS.Default
	local button = Create.new("TextButton", {
		Name = options.Name or "Button",
		Size = options.Size or UDim2.fromOffset(0, 38),
		AutomaticSize = if options.Size then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
		LayoutOrder = options.LayoutOrder or 0,
		Text = options.Title or "",
		Weight = "medium",
		Theme = { BackgroundColor3 = roles.fill, TextColor3 = roles.text },
		Parent = parent,
	})
	Create.corner(8, button)
	Create.padding(button, 16, 0)
	local function paint(role)
		Theme.bind(button, "BackgroundColor3", role, true)
		Motion.tween(button, "fast", { BackgroundColor3 = Theme.color(role) })
	end
	scope:connect(button.MouseEnter, function()
		paint(roles.hover)
	end)
	scope:connect(button.MouseLeave, function()
		paint(roles.fill)
	end)
	Effects.apply(scope, button, options.Effect or "Sweep", 8)
	return button
end

-- The scrim and an empty card. Returns { card, scope, Close, Closed }.
function Dialog.shell(library, options)
	local overlay = Mount.overlay(library)
	local scope = library.scope:child()
	local shell = { scope = scope, Closed = false }

	local scrim = Create.new("TextButton", {
		Name = "Dialog",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Parent = overlay.dialogs,
	})
	scope:add(scrim)
	Motion.tween(scrim, "base", { BackgroundTransparency = 0.45 })

	local card = Create.new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -32, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Active = true,
		Theme = { BackgroundColor3 = "surface" },
		Parent = scrim,
	})
	Create.new("UISizeConstraint", { MaxSize = Vector2.new(options.Width or 380, math.huge), Parent = card })
	Create.corner(12, card)
	Create.stroke("stroke", card)
	Create.padding(card, 18)
	Create.list(card, "Vertical", 10)
	shell.card = card
	-- The card rises the last few pixels into place.
	card.Position = UDim2.new(0.5, 0, 0.5, 14)
	Motion.tween(card, "base", { Position = UDim2.fromScale(0.5, 0.5) })

	function shell.Close()
		if shell.Closed then
			return
		end
		shell.Closed = true
		library.scope:release(scope)
		if options.OnClose then
			options.OnClose()
		end
	end

	if options.Dismissible then
		scope:connect(scrim.Activated, shell.Close)
	end
	return shell
end

function Dialog.heading(parent, title, icon)
	local head = Create.new("Frame", { Name = "Heading", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = parent })
	Create.list(head, "Horizontal", 10)
	if icon then
		Create.icon(icon, 20, "accent", head)
	end
	Create.new("TextLabel", {
		Name = "Title",
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 16,
		Weight = "bold",
		TextWrapped = true,
		LayoutOrder = 1,
		Text = title or "",
		Theme = { TextColor3 = "text" },
		Parent = head,
	}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	return head
end

function Dialog.text(parent, content, order)
	return Create.new("TextLabel", {
		Name = "Content",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 13,
		LayoutOrder = order or 1,
		Text = content or "",
		Theme = { TextColor3 = "textMuted" },
		Parent = parent,
	})
end

-- Options: Title, Content, Icon, Dismissible, and Buttons as a list of
-- { Title, Variant = "Primary" | "Danger", Callback }. Name each button by
-- its outcome ("Delete", "Keep"), not "Yes" or "OK".
function Dialog.open(library, options)
	local shell = Dialog.shell(library, options)
	Dialog.heading(shell.card, options.Title, options.Icon)
	if options.Content then
		Dialog.text(shell.card, options.Content, 1)
	end

	local actions = Create.new("Frame", { Name = "Actions", Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 2, Parent = shell.card })
	Create.list(actions, "Horizontal", 8, { HorizontalAlignment = Enum.HorizontalAlignment.Right })
	for index, settings in options.Buttons or { { Title = "Close" } } do
		local button = Dialog.button(shell.scope, actions, { Title = settings.Title, Variant = settings.Variant, LayoutOrder = index })
		shell.scope:connect(button.Activated, function()
			shell.Close()
			Env.call(settings.Title or "Dialog", settings.Callback)
		end)
	end
	return shell
end

return Dialog
