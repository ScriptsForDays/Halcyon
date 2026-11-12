-- Panels hub developers otherwise build by hand: a loading screen that
-- reports real setup work, a "What's new" card shown once per version, an
-- About section, empty and error states for a tab, and a lock screen.

local Create = require("../Core/Create")
local Dialog = require("./Dialog")
local Env = require("../Core/Env")
local Motion = require("../Core/Motion")

local TAGS = {
	New = "accent",
	Improved = "info",
	Fixed = "success",
	Removed = "danger",
	Security = "warning",
}

local Panels = {}

-- A card laid over the window's body, taking every press under it.
local function cover(window, name)
	local veil = Create.new("TextButton", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		BackgroundTransparency = 0.04,
		Theme = { BackgroundColor3 = "background" },
		Parent = window.body,
	})
	local card = Create.new("Frame", {
		Name = "Card",
		Size = UDim2.new(1, -48, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 51,
		Parent = veil,
	})
	Create.new("UISizeConstraint", { MaxSize = Vector2.new(320, math.huge), Parent = card })
	Create.list(card, "Vertical", 10, { HorizontalAlignment = Enum.HorizontalAlignment.Center })
	return veil, card
end

local function line(card, text, size, role, weight, order)
	return Create.new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = text or "",
		TextSize = size,
		Weight = weight,
		LayoutOrder = order,
		ZIndex = 52,
		Theme = { TextColor3 = role },
		Parent = card,
	})
end

-- A loading screen over the window while the hub sets itself up. It only
-- moves when the hub reports progress; there is no pretend timer.
-- Options: Title, Text, Icon. Returns { SetProgress(fraction, text), Done() }.
function Panels.loading(window, options)
	options = options or {}
	local scope = window.scope:child()
	local veil, card = cover(window, "Loading")
	veil.BackgroundTransparency = 0
	scope:add(veil)
	local icon = Create.icon(options.Icon or window.Icon or "sparkles", 32, "accent", card)
	icon.ZIndex = 52
	line(card, options.Title or window.Title, 16, "text", "bold", 1)
	local status = line(card, options.Text or "Getting ready", 13, "textMuted", "regular", 2)
	local rail = Create.new("Frame", { Name = "Rail", Size = UDim2.new(1, 0, 0, 4), LayoutOrder = 3, ZIndex = 52, Theme = { BackgroundColor3 = "raised" }, Parent = card })
	Create.corner(-1, rail)
	local fill = Create.new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), ZIndex = 53, Theme = { BackgroundColor3 = "accent" }, Parent = rail })
	Create.corner(-1, fill)

	local loader = { done = false }
	function loader.SetProgress(fraction, text)
		fraction = math.clamp(tonumber(fraction) or 0, 0, 1)
		Motion.tween(fill, "base", { Size = UDim2.fromScale(fraction, 1) })
		if text then
			status.Text = tostring(text)
		end
	end
	function loader.Done()
		if loader.done then
			return
		end
		loader.done = true
		loader.SetProgress(1)
		Motion.tween(veil, "base", { BackgroundTransparency = 1 })
		task.delay(if Motion.reduced then 0 else 0.25, function()
			window.scope:release(scope)
		end)
	end
	return loader
end

-- A "What's new" card shown once for each version the player has not seen.
-- Options: Version (required), Title, Entries ({ { Kind = "New" |
-- "Improved" | "Fixed" | "Removed", Text } } or plain strings), Force
-- (show even if seen). Returns the dialog, or nil when already seen.
function Panels.changelog(window, options)
	options = options or {}
	local version = tostring(options.Version or window.options.Version or "")
	if version == "" then
		error("Changelog needs a Version", 3)
	end
	if window.changelogSeen == version and not options.Force then
		return nil
	end
	local shell = Dialog.shell(window.library, { Width = 400, Dismissible = true })
	Dialog.heading(shell.card, options.Title or `What's new in {version}`, options.Icon or "sparkles")
	local list = Create.new("Frame", { Name = "Entries", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = shell.card })
	Create.list(list, "Vertical", 8)
	for index, entry in options.Entries or {} do
		local kind, text = "New", entry
		if type(entry) == "table" then
			kind, text = entry.Kind or "New", entry.Text
		end
		local item = Create.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = index, Parent = list })
		Create.list(item, "Horizontal", 8, { VerticalAlignment = Enum.VerticalAlignment.Top })
		local role = TAGS[kind] or "accent"
		local tag = Create.new("TextLabel", {
			Size = UDim2.fromOffset(88, 18),
			Text = string.upper(kind),
			TextSize = 12,
			Weight = "bold",
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0.82,
			Theme = { BackgroundColor3 = role, TextColor3 = role },
			Parent = item,
		})
		Create.corner(4, tag)
		Create.new("TextLabel", {
			Size = UDim2.fromScale(0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 13,
			LayoutOrder = 1,
			Text = tostring(text or ""),
			Theme = { TextColor3 = "text" },
			Parent = item,
		}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	end
	local actions = Create.new("Frame", { Name = "Actions", Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 2, Parent = shell.card })
	Create.list(actions, "Horizontal", 8, { HorizontalAlignment = Enum.HorizontalAlignment.Right })
	local close = Dialog.button(shell.scope, actions, { Title = options.Button or "Continue", Variant = "Primary" })
	shell.scope:connect(close.Activated, shell.Close)
	window.changelogSeen = version
	window:savePreferences()
	return shell
end

-- An About section: what the hub is, who made it, and links the player can
-- copy. Options: Title, Description, Credits ({ { Name, Role } }), Discord
-- (an invite link), Links ({ { Title, Url } }), Side.
function Panels.about(window, tab, options)
	options = options or {}
	local section = tab:Section({ Title = options.Title or "About", Icon = "info", Side = options.Side })
	section:Paragraph({ Title = window.Title, Content = options.Description or window.Subtitle or "", Icon = window.Icon })
	if window.options.Version then
		section:Status({ Title = "Version", Status = tostring(window.options.Version), Kind = "info" })
	end
	for _, credit in options.Credits or {} do
		section:Label({ Title = `<b>{credit.Name or ""}</b>  {credit.Role or ""}` })
	end
	local links = table.clone(options.Links or {})
	if options.Discord then
		table.insert(links, 1, { Title = "Discord", Url = options.Discord, Icon = "message-circle" })
	end
	for _, link in links do
		section:Button({
			Title = link.Title or "Link",
			Description = tostring(link.Url),
			TrailingIcon = "copy",
			Callback = function()
				local copied = Env.copy(tostring(link.Url))
				window:Notify({
					Title = if copied then "Link copied" else "Copy not supported",
					Content = if copied then "Paste it into your browser." else tostring(link.Url),
					Kind = if copied then "success" else "info",
					Style = "Compact",
				})
			end,
		})
	end
	return section
end

-- A centred card on a tab with nothing to show yet, or that failed to
-- load. Options: Icon, Title, Text, Kind ("empty" or "error"), Button
-- ({ Title, Callback }). Returns { Destroy }.
function Panels.state(tab, options)
	options = options or {}
	local scope = tab.scope:child()
	local failed = options.Kind == "error"
	local frame = Create.new("Frame", {
		Name = "State",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = tab.notices.Parent,
	})
	scope:add(frame)
	Create.padding(frame, 24, 36)
	Create.list(frame, "Vertical", 8, { HorizontalAlignment = Enum.HorizontalAlignment.Center })
	local disc = Create.new("Frame", {
		Size = UDim2.fromOffset(52, 52),
		BackgroundTransparency = 0.85,
		Theme = { BackgroundColor3 = if failed then "danger" else "accent" },
		Parent = frame,
	})
	Create.corner(-1, disc)
	local glyph = Create.icon(options.Icon or (if failed then "circle-alert" else "box"), 24, if failed then "danger" else "accent", disc)
	glyph.AnchorPoint, glyph.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	local title = Create.new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		Text = options.Title or (if failed then "Something went wrong" else "Nothing here yet"),
		TextSize = 15,
		Weight = "bold",
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
		Theme = { TextColor3 = "text" },
		Parent = frame,
	})
	local text = Create.new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Text = options.Text or "",
		Visible = options.Text ~= nil,
		Theme = { TextColor3 = "textMuted" },
		Parent = frame,
	})
	if options.Button then
		local button = Dialog.button(scope, frame, { Title = options.Button.Title or "Try again", Variant = if failed then "Default" else "Primary", LayoutOrder = 3 })
		scope:connect(button.Activated, function()
			Env.call(options.Button.Title or "State", options.Button.Callback)
		end)
	end
	local state = {}
	function state.SetText(_, newTitle, newText)
		title.Text = newTitle or title.Text
		if newText then
			text.Text, text.Visible = newText, true
		end
	end
	function state.Destroy()
		tab.scope:release(scope)
	end
	return state
end

-- Blocks the whole window with a message: maintenance, a required update,
-- a ban notice from the hub's own service. Options: Title, Text, Icon,
-- Button ({ Title, Callback }). Window:Unlock() removes it.
function Panels.lock(window, options)
	options = if type(options) == "string" then { Text = options } else options or {}
	Panels.unlock(window)
	local scope = window.scope:child()
	local veil, card = cover(window, "LockScreen")
	-- Solid: the controls under a lock should not show through.
	veil.BackgroundTransparency = 0
	scope:add(veil)
	local disc = Create.new("Frame", { Size = UDim2.fromOffset(56, 56), ZIndex = 52, BackgroundTransparency = 0.85, Theme = { BackgroundColor3 = "warning" }, Parent = card })
	Create.corner(-1, disc)
	local glyph = Create.icon(options.Icon or "wrench", 26, "warning", disc)
	glyph.AnchorPoint, glyph.Position, glyph.ZIndex = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), 53
	line(card, options.Title or "Unavailable right now", 16, "text", "bold", 1)
	line(card, options.Text or "", 13, "textMuted", "regular", 2)
	if options.Button then
		local button = Dialog.button(scope, card, { Title = options.Button.Title or "OK", Variant = "Primary", LayoutOrder = 3 })
		button.ZIndex = 52
		scope:connect(button.Activated, function()
			Env.call(options.Button.Title or "Lock", options.Button.Callback)
		end)
	end
	window.lockScreen = scope
end

function Panels.unlock(window)
	if window.lockScreen then
		window.scope:release(window.lockScreen)
		window.lockScreen = nil
	end
end

return Panels
