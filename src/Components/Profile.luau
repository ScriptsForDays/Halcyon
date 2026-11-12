-- The user card: avatar, name, executor and clock. Anonymous mode swaps the
-- avatar for a placeholder and the names for neutral text, so a screenshot
-- or a stream does not show who is playing.

local Players = game:GetService("Players")

local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Popup = require("./Popup")

local DEFAULTS = {
	Enabled = true,
	Avatar = "Headshot",
	Anonymous = false,
	ShowUsername = true,
	ShowTier = true,
	ShowExecutor = true,
	ShowClock = true,
	ShowDate = false,
	ClockFormat = "%H:%M",
	DateFormat = "%d %b %Y",
}

local Profile = {}

-- `false` turns the card off; a table overrides individual defaults.
function Profile.settings(options)
	local settings = table.clone(DEFAULTS)
	if options == false then
		settings.Enabled = false
	elseif type(options) == "table" then
		for key, value in options do
			settings[key] = value
		end
	end
	return settings
end

local function formatted(pattern)
	local ok, text = pcall(os.date, pattern)
	return if ok and type(text) == "string" then text else ""
end

-- The line under the name: executor, date and time, whichever are enabled.
function Profile.meta(settings)
	local parts = {}
	if settings.ShowExecutor then
		table.insert(parts, (Env.executor()))
	end
	if settings.ShowDate then
		table.insert(parts, formatted(settings.DateFormat))
	end
	if settings.ShowClock then
		table.insert(parts, formatted(settings.ClockFormat))
	end
	return table.concat(parts, " · ")
end

function Profile.names(settings)
	if settings.Anonymous then
		return "Anonymous", "Identity hidden"
	end
	local player = Players.LocalPlayer
	return settings.Name or player.DisplayName, settings.Subtitle or ("@" .. player.Name)
end

-- Puts a copy of the player's character in the viewport, framed on the head.
-- Returns false when there is no character to show yet.
local function stage(view)
	local character = Players.LocalPlayer.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return false
	end
	local archivable = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(character.Clone, character)
	character.Archivable = archivable
	if not ok or not copy then
		return false
	end
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("Sound") then
			descendant:Destroy()
		end
	end

	local world = Instance.new("WorldModel")
	copy.Parent = world
	world.Parent = view
	local focus = head.Position
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(focus + head.CFrame.LookVector * 2.4 + Vector3.new(0, 0.15, 0), focus)
	camera.Parent = view
	view.CurrentCamera = camera
	return true
end

local function avatar(window, scope, parent, size)
	local settings = window.profile
	local holder = Create.new("Frame", {
		Name = "Avatar",
		Size = UDim2.fromOffset(size, size),
		Theme = { BackgroundColor3 = "raised" },
		Parent = parent,
	})
	Create.corner(-1, holder)

	if settings.Anonymous or settings.Avatar == "None" then
		local glyph = Create.icon("user", math.floor(size / 2), "textMuted", holder)
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(0.5, 0.5)
		return holder
	end

	if settings.Avatar == "Viewport" then
		local view = Create.new("ViewportFrame", { Size = UDim2.fromScale(1, 1), Parent = holder })
		Create.corner(-1, view)
		if stage(view) then
			return holder
		end
		view:Destroy()
	end

	local picture = Create.new("ImageLabel", { Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Crop, Parent = holder })
	Create.corner(-1, picture)
	task.spawn(function()
		local ok, content = pcall(Players.GetUserThumbnailAsync, Players, Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		if ok and not scope.cleaned then
			picture.Image = content
		end
	end)
	return holder
end

local function line(parent, text, order, size, weight, role)
	return Create.new("TextLabel", {
		Size = UDim2.new(1, 0, 0, size + 3),
		Text = text,
		TextSize = size,
		Weight = weight,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = order,
		Visible = text ~= "",
		Theme = { TextColor3 = role },
		Parent = parent,
	})
end

-- The full card: avatar with three lines of text beside it.
function Profile.card(window, scope, parent)
	local settings = window.profile
	local card = Create.new("Frame", {
		Name = "Profile",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = parent,
	})
	Create.padding(card, 12, 10)
	Create.list(card, "Horizontal", 10)
	avatar(window, scope, card, 36)

	local text = Create.new("Frame", { Name = "Text", AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = card }, {
		Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
	})
	Create.list(text, "Vertical", 0)
	local name, username = Profile.names(settings)
	local heading = Create.new("Frame", { Name = "Heading", Size = UDim2.new(1, 0, 0, 18), Parent = text })
	Create.list(heading, "Horizontal", 6)
	Create.new("TextLabel", {
		Name = "Name",
		Size = UDim2.fromScale(0, 1),
		Text = name,
		TextSize = 13,
		Weight = "bold",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = "text" },
		Parent = heading,
	}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	line(text, if settings.ShowUsername then username else "", 1, 12, "regular", "textMuted")
	-- The tier badge has a line of its own under the others: the sidebar is
	-- too narrow to share one without cutting the name or username short.
	if settings.ShowTier then
		local tierLine = Create.new("Frame", { Name = "TierLine", Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 4, Parent = text })
		Create.padding(tierLine, 0, 3, 0, 0)
		-- The tier the player holds: Keyless, or a key system tier. Paid tiers take the accent.
		local paid = window:IsPaid()
		local access = window.access
		local icon = access.Icon or (if paid then "crown" elseif access.Keyless or access.NoKey then "lock-open" else "key")
		local badge = Create.new("Frame", {
			Name = "TierBadge",
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 1,
			Theme = { BackgroundColor3 = if paid then "accent" else "raised" },
			Parent = tierLine,
		})
		Create.corner(5, badge)
		Create.padding(badge, 6, 0)
		Create.list(badge, "Horizontal", 4)
		Create.icon(icon, 11, if paid then "onAccent" else "textMuted", badge)
		Create.new("TextLabel", {
			Name = "Tier",
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = window:GetTier(),
			TextSize = 11,
			Weight = "medium",
			LayoutOrder = 1,
			Theme = { TextColor3 = if paid then "onAccent" else "textMuted" },
			Parent = badge,
		})
	end
	local meta = line(text, Profile.meta(settings), 2, 12, "regular", "textMuted")
	local expiry
	if window.access.ExpiresAt and window.access.ShowExpiry then
		expiry = line(text, "", 3, 12, "medium", "warning")
		expiry.Name = "Expiry"
	end
	local function countdown()
		if expiry then
			local left = window:GetKeyExpiry()
			expiry.Text = if left > 0 then `Key expires in {Env.duration(left)}` else "Key expired"
			expiry.Visible = true
		end
	end
	countdown()

	if settings.ShowClock or expiry then
		window:everySecond(scope, function()
			meta.Text = Profile.meta(settings)
			countdown()
		end)
	end
	return card
end

-- The avatar alone, for narrow navigation. A press opens the full card.
function Profile.chip(window, scope, parent)
	local chip = Create.new("TextButton", { Name = "ProfileChip", Size = UDim2.fromOffset(44, 44), Parent = parent })
	local picture = avatar(window, scope, chip, 28)
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, 0.5)
	scope:connect(chip.Activated, function()
		local popup = Popup.toggle(window.library, chip, { Width = 230 })
		if popup then
			Profile.card(window, popup.scope, popup.frame)
		end
	end)
	return chip
end

return Profile
