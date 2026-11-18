-- Buttons. The look comes from the style registry (kind "Button"): "Row"
-- makes the whole row the button, with a mark on the right; the others draw
-- a full-width button.
--
-- Options beyond the row's own: Variant or Style (the look), Icon (inside a
-- drawn button), TrailingIcon (the row look's mark), Effect (Sweep, Ripple,
-- Lift, Glow, Press, Fill or None), Hold (seconds to hold before it runs),
-- Confirm (true or the wording of a second press that confirms), ShowDone
-- (a brief tick, or a cross if the Callback failed).

local Create = require("../Core/Create")
local Effects = require("../Core/Effects")
local Icons = require("../Core/Icons")
local Motion = require("../Core/Motion")
local Row = require("./Row")
local Strings = require("../Core/Strings")
local Styles = require("../Core/Styles")
local Theme = require("../Core/Theme")

local CONFIRM_WINDOW = 3
local FLASH = 1.2

-- fill, hover, text: theme roles. fillTransparency: for tinted looks.
-- stroke: an outline role. gradient: the fill runs into accentHover.
Styles.register("Button", "Row", { row = true })
Styles.register("Button", "Filled", { fill = "accent", hover = "accentHover", text = "onAccent" })
Styles.register("Button", "Outline", { fill = "raised", hover = "hover", text = "text", stroke = "stroke" })
Styles.register("Button", "Danger", { fill = "danger", hover = "danger", text = "onAccent" })
Styles.register("Button", "Soft", { fill = "accent", fillTransparency = 0.82, hover = "accent", hoverTransparency = 0.72, text = "accent" })
Styles.register("Button", "Ghost", { fill = "hover", fillTransparency = 1, hover = "hover", hoverTransparency = 0, text = "text" })
Styles.register("Button", "Gradient", { fill = "accent", hover = "accentHover", text = "onAccent", gradient = true })
Styles.register("Button", "Success", { fill = "success", hover = "success", text = "onAccent" })

local Button = {}

function Button.new(container, options)
	local look = Styles.pick("Button", options.Variant or options.Style, container.window)
	local row, handle, target, label, indicator
	local title = options.Title or ""

	if look.row then
		row = Row.new(container, options, { button = true })
		handle, target, label = row.handle, row.frame, row.title
		indicator = Create.icon(options.TrailingIcon or "chevron-right", 16, "textMuted", row.slot)
		row.onHover(function(active)
			Theme.bind(indicator, "ImageColor3", if active then "accent" else "textMuted")
		end)
	else
		row = Row.new(container, options, { bare = true })
		handle = row.handle
		target = Create.new("TextButton", {
			Name = "Button",
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = look.fillTransparency or 0,
			Theme = { BackgroundColor3 = look.fill },
			Parent = row.content,
		})
		Create.corner(8, target)
		if look.stroke then
			Create.stroke(look.stroke, target)
		end
		if look.gradient then
			-- The gradient tints a white-based fill, so the colour comes from the
			-- gradient's own keypoints, kept in step with the theme.
			local gradient = Create.new("UIGradient", { Rotation = 20, Parent = target })
			local function tint()
				gradient.Color = ColorSequence.new(Theme.color("accent"), Theme.color("accentHover"))
			end
			tint()
			row.scope:connect(Theme.Changed, tint)
		end
		local inner = Create.new("Frame", {
			Name = "Inner",
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			ZIndex = 3,
			Parent = target,
		})
		Create.list(inner, "Horizontal", 8)
		indicator = Create.icon(options.Icon or "check", 16, look.text, inner)
		indicator.Visible = options.Icon ~= nil
		label = Create.new("TextLabel", {
			Name = "Label",
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = title,
			Weight = "medium",
			LayoutOrder = 2,
			Theme = { TextColor3 = look.text },
			Parent = inner,
		})
		local function paint(hovered)
			local role = if hovered then look.hover else look.fill
			Theme.bind(target, "BackgroundColor3", role, true)
			Motion.tween(target, "fast", {
				BackgroundColor3 = Theme.color(role),
				BackgroundTransparency = if hovered then look.hoverTransparency or look.fillTransparency or 0 else look.fillTransparency or 0,
			})
		end
		row.scope:connect(target.MouseEnter, function()
			paint(true)
		end)
		row.scope:connect(target.MouseLeave, function()
			paint(false)
		end)
		Effects.apply(row.scope, target, options.Effect or row.window.styles.ButtonEffect or row.window.buttonEffect, 8)
	end

	-- The spinner stands where the indicator icon is while the button is busy.
	local spinner = Effects.spinner(row.scope, indicator.Parent, 14, if look.row then "accent" else look.text)
	spinner.frame.LayoutOrder = indicator.LayoutOrder
	local busy, armed, flashing = false, false, 0
	local resting = { icon = if look.row then options.TrailingIcon or "chevron-right" else options.Icon, visible = indicator.Visible }

	local function setText(text)
		if label then
			label.Text = text
		end
	end

	-- Shows a tick or cross for a moment, then the button's own state again.
	local function flash(ok)
		flashing += 1
		local mine = flashing
		Icons.apply(indicator, if ok then "check" else "x")
		Theme.bind(indicator, "ImageColor3", if ok then "success" else "danger")
		indicator.Visible = true
		task.delay(FLASH, function()
			if mine ~= flashing or row.scope.cleaned then
				return
			end
			indicator.Visible = resting.visible
			if resting.icon then
				Icons.apply(indicator, resting.icon)
			end
			Theme.bind(indicator, "ImageColor3", if look.row then "textMuted" else look.text)
		end)
	end

	local function run()
		if busy then
			return
		end
		if options.ShowDone then
			handle.Changed:Fire()
			row.run(options.Callback, flash)
		else
			row.fire()
		end
	end

	-- A first press arms the button and changes its wording; a second within
	-- three seconds runs it.
	local confirmText = if type(options.Confirm) == "string" then options.Confirm else Strings.get("Press again to confirm")
	local function activate()
		if busy then
			return
		end
		if options.Confirm and not armed then
			armed = true
			setText(confirmText)
			task.delay(CONFIRM_WINDOW, function()
				if armed and not row.scope.cleaned then
					armed = false
					setText(handle.Title)
				end
			end)
			return
		end
		if armed then
			armed = false
			setText(handle.Title)
		end
		run()
	end

	local hold = if options.Hold == true then 1 elseif type(options.Hold) == "number" then options.Hold else nil
	if hold then
		-- Holding fills the button; letting go early empties it again.
		local bar = Create.new("Frame", {
			Name = "Hold",
			Size = UDim2.fromScale(0, 1),
			BackgroundTransparency = 0.7,
			Theme = { BackgroundColor3 = if look.row then "accent" else "text" },
			Parent = Effects.layer(target, 8),
		})
		local holding = 0
		local function release()
			holding += 1
			Motion.tween(bar, "fast", { Size = UDim2.fromScale(0, 1) })
		end
		row.scope:connect(target.InputBegan, function(input)
			local kind = input.UserInputType
			if busy or (kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch) then
				return
			end
			holding += 1
			local mine = holding
			bar.Size = UDim2.fromScale(0, 1)
			Motion.tween(bar, TweenInfo.new(hold, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
			task.delay(hold, function()
				if mine == holding and not row.scope.cleaned then
					release()
					run()
				end
			end)
		end)
		row.scope:connect(target.InputEnded, function(input)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
				release()
			end
		end)
		row.scope:connect(target.MouseLeave, release)
	else
		row.scope:connect(target.Activated, activate)
	end

	function handle:SetTitle(text)
		self.Title = text
		armed = false
		setText(text)
		self.SearchText = string.lower(text)
	end

	-- While loading, presses are ignored and a spinner turns; `text`
	-- optionally replaces the wording until loading ends.
	function handle:SetLoading(loading, text)
		busy = loading == true
		if busy then
			spinner.start()
			indicator.Visible = false
			if text then
				setText(text)
			end
		else
			spinner.stop()
			indicator.Visible = resting.visible
			setText(self.Title)
		end
	end

	function handle:IsLoading()
		return busy
	end

	-- A callback that yields shows the spinner until it returns, unless the
	-- hub is already driving SetLoading itself.
	local ownLoading = false
	function row.busy(on)
		if on and not busy then
			ownLoading = true
			handle:SetLoading(true)
		elseif not on and ownLoading then
			ownLoading = false
			handle:SetLoading(false)
		end
	end

	function handle:Press()
		run()
	end

	return handle
end

return Button
