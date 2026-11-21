-- The key prompt. Tiers are ordered lowest to highest ("Free", "Paid", or
-- any names the hub defines); the tier a key unlocks decides what the window
-- leaves locked.
--
-- This runs on the player's machine, so it is a gate for honest users and
-- not a security boundary: anyone who can read the script can skip it. To
-- really protect a script, have your server hand it out only after the key
-- is validated there.

local Create = require("../Core/Create")
local Dialog = require("./Dialog")
local DiscordButton = require("./DiscordButton")
local Env = require("../Core/Env")
local Hairline = require("../Core/Hairline")
local Motion = require("../Core/Motion")
local Strings = require("../Core/Strings")
local Translate = require("../Core/Translate")
local Theme = require("../Core/Theme")

local VERSION = 1
local INVALID_KEY_MESSAGE = "That key is not valid."

local KeySystem = {}

local function trim(text)
	return string.match(tostring(text or ""), "^%s*(.-)%s*$")
end

-- `Tiers` may be left out for a single tier described by the top-level
-- Keys, Validate, Remote and Link.
-- Free means a key the player earns, usually through the hub's ad link;
-- a tier that needs no key at all is Keyless, and takes that name unless
-- the hub gives it another.
function KeySystem.tiers(options)
	if type(options.Tiers) == "table" and #options.Tiers > 0 then
		local tiers = {}
		for index, tier in options.Tiers do
			if tier.Name == nil and tier.NoKey then
				tier = table.clone(tier)
				tier.Name = "Keyless"
			end
			tiers[index] = tier
		end
		return tiers
	end
	return { { Name = "Access", Keys = options.Keys, Remote = options.Remote, Link = options.Link } }
end

local function tierIndex(tiers, name)
	for index, tier in tiers do
		if tier.Name == name then
			return index
		end
	end
	return nil
end

-- Asks the hub's own server. By default the key is sent as JSON in a POST
-- body and the reply must be JSON with `valid = true`; Body and Accept
-- replace either half.
local function remoteCheck(remote, key)
	local url = if type(remote.Url) == "function" then remote.Url(key) else remote.Url
	local method = remote.Method or "POST"
	local body
	if method ~= "GET" then
		if type(remote.Body) == "function" then
			body = remote.Body(key)
		else
			local _, text = Env.encode({ key = key })
			body = text
		end
	end
	local ok, response, status = Env.http({
		Url = url,
		Method = method,
		Headers = remote.Headers or { ["Content-Type"] = "application/json" },
		Body = body,
	})
	if type(remote.Accept) == "function" then
		local valid, detail = remote.Accept(response, status)
		return valid == true, detail
	end
	if not ok then
		return false, if status == 0 then Strings.get("The key server could not be reached.") else nil
	end
	local decoded, reply = Env.decode(response)
	if not decoded or type(reply) ~= "table" then
		return false, nil
	end
	return reply.valid == true, if type(reply.message) == "string" then reply.message else nil
end

-- The ad service a tier is tied to, if it names one.
local function adService(tier)
	return if tier and type(tier.AdService) == "table" then tier.AdService else nil
end

-- Returns the index of the tier the key unlocks and whatever else the
-- validator returned, or nil and a message.
-- Listed keys are checked across every tier, highest first, so a paid key
-- works whichever tier is selected; the ad service, Validate and Remote run
-- for the selected tier only. May yield while a validator talks to a server.
--
-- An ad service proves nothing by itself here: its Confirm or Remote asks
-- the hub's server (or the service's API) whether this player finished the
-- ad, and only that answer unlocks the tier.
function KeySystem.check(options, selected, key)
	local tiers = KeySystem.tiers(options)
	local tier = tiers[selected]
	local ad = adService(tier)
	-- With RequiresKey = false the service confirms the player with no key to type.
	local keyed = not (ad and ad.RequiresKey == false)
	key = trim(key)
	if key == "" and keyed then
		return nil, Strings.get("Enter your key first.")
	end
	if key ~= "" then
		for index = #tiers, 1, -1 do
			local keys = tiers[index].Keys
			if type(keys) == "table" and table.find(keys, key) then
				return index, nil, nil
			end
		end
	end

	local message
	local function passed(valid, detail)
		if not valid and type(detail) == "string" then
			message = detail
		end
		return valid == true, detail
	end
	local ok, unlocked, detail = pcall(function()
		if ad and type(ad.Confirm) == "function" then
			local valid, extra = passed(ad.Confirm(if keyed then key else nil))
			if valid then
				return selected, extra
			end
		end
		if ad and type(ad.Remote) == "table" then
			local valid, extra = passed(remoteCheck(ad.Remote, key))
			if valid then
				return selected, extra
			end
		end
		if key == "" then
			return nil, nil
		end
		if tier and type(tier.Validate) == "function" then
			local valid, extra = passed(tier.Validate(key))
			if valid then
				return selected, extra
			end
		end
		if tier and type(tier.Remote) == "table" then
			local valid, extra = passed(remoteCheck(tier.Remote, key))
			if valid then
				return selected, extra
			end
		end
		if type(options.Validate) == "function" then
			local answer, extra = options.Validate(key)
			local index = if type(answer) == "string" then tierIndex(tiers, answer) elseif answer then selected else nil
			if index then
				return index, extra
			end
			passed(false, extra)
		end
		return nil, nil
	end)
	if not ok then
		warn(`[Halcyon] Key validator failed: {unlocked}`)
		return nil, Strings.get("The key could not be checked. Try again.")
	elseif unlocked then
		return unlocked, nil, detail
	end
	if not message and ad and not keyed then
		message = Strings.get("The {service} step is not confirmed yet. Finish it, then try again.", { service = ad.Name or Strings.get("ad") })
	end
	return nil, message or Strings.get(INVALID_KEY_MESSAGE)
end

local function savedPath(folder)
	return `Halcyon/{folder}/key.json`
end

-- A saved key is checked again on every run; one that expired or stopped
-- validating is forgotten and the prompt shows.
local function loadSaved(options, folder)
	if options.SaveKey == false then
		return nil
	end
	local content = Env.read(savedPath(folder))
	local decoded, saved = false, nil
	if content then
		decoded, saved = Env.decode(content)
	end
	if not decoded or type(saved) ~= "table" or saved.version ~= VERSION or type(saved.key) ~= "string" or type(saved.savedAt) ~= "number" then
		return nil
	end
	local tiers = KeySystem.tiers(options)
	local index = tierIndex(tiers, saved.tier)
	local duration = index and tiers[index].Duration
	if not index or (duration and os.time() - saved.savedAt >= duration) then
		Env.remove(savedPath(folder))
		return nil
	end
	local unlocked = KeySystem.check(options, index, saved.key)
	if not unlocked then
		Env.remove(savedPath(folder))
		return nil
	end
	return unlocked, saved.key, if duration then saved.savedAt + duration else nil
end

-- Shows the prompt and yields until a key is accepted or the prompt is
-- closed. Returns { Tier, Rank, Tiers, Key, Saved, Data } or nil.
function KeySystem.prompt(library, options, context)
	local tiers = KeySystem.tiers(options)
	local names = {}
	for index, tier in tiers do
		names[index] = tier.Name
	end
	-- A tier is paid when it says so, or by default when it is named "Paid".
	-- Tiers ranked above a paid one count as paid too.
	local paidRank
	for index, tier in tiers do
		if paidRank == nil and (tier.Paid == true or (tier.Paid == nil and tier.Name == "Paid")) then
			paidRank = index
		end
	end
	-- ShowExpiry = false keeps a key's expiry off the prompt and the profile card.
	local showExpiry = options.ShowExpiry ~= false
	local function access(index, key, saved, detail, expiresAt)
		return {
			Tier = names[index],
			Rank = index,
			Tiers = names,
			PaidRank = paidRank,
			Key = key,
			Saved = saved,
			Data = detail,
			ExpiresAt = expiresAt,
			ShowExpiry = showExpiry,
			Icon = tiers[index].Icon,
			NoKey = tiers[index].NoKey == true,
		}
	end

	local savedIndex, savedKey, savedExpiry = loadSaved(options, context.folder)
	if savedIndex then
		return access(savedIndex, savedKey, true, nil, savedExpiry)
	end

	local outcome, done, waiter = nil, false, nil
	local shell = Dialog.shell(library, {
		Width = 430,
		OnClose = function()
			done = true
			if waiter then
				task.spawn(waiter)
			end
		end,
	})
	local card, scope = shell.card, shell.scope
	local selected = tierIndex(tiers, options.DefaultTier) or 1
	local maxAttempts, cooldown = options.MaxAttempts or 5, options.Cooldown or 30
	local attempts, busy, locked = 0, false, false

	local effect = options.ButtonEffect or "Sweep"

	-- Header: an accent tile carrying the icon, the title, the note and the
	-- close button.
	local header = Create.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = card,
	})
	Create.list(header, "Horizontal", 12, { VerticalAlignment = Enum.VerticalAlignment.Top })
	local tile = Create.new("Frame", {
		Name = "Tile",
		Size = UDim2.fromOffset(44, 44),
		BackgroundTransparency = 0.85,
		Theme = { BackgroundColor3 = "accent" },
		Parent = header,
	})
	Create.corner(12, tile)
	Create.new("UIStroke", { Transparency = 0.55, Theme = { Color = "accent" }, Parent = tile })
	local glyph = Create.icon(options.Icon or "key-round", 22, "accent", tile)
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	local titles = Create.new("Frame", { Name = "Titles", AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = header }, {
		Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
	})
	Create.list(titles, "Vertical", 3)
	Create.new("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 17,
		Weight = "bold",
		Text = options.Title or Strings.get("{title} access", { title = context.title }),
		Theme = { TextColor3 = "text" },
		Parent = titles,
	})
	Create.new("TextLabel", {
		Name = "Note",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 13,
		LayoutOrder = 1,
		Text = options.Note or "",
		Visible = (options.Note or "") ~= "",
		Theme = { TextColor3 = "textMuted" },
		Parent = titles,
	})
	local close = Create.new("TextButton", { Name = "Close", Size = UDim2.fromOffset(32, 32), LayoutOrder = 2, Parent = header })
	Create.corner(8, close)
	local cross = Create.icon("x", 16, "textMuted", close)
	cross.AnchorPoint = Vector2.new(0.5, 0.5)
	cross.Position = UDim2.fromScale(0.5, 0.5)
	scope:connect(close.Activated, shell.Close)
	Hairline.new("X", "stroke", { LayoutOrder = 1, Parent = card })

	-- One card per tier, side by side: icon, name, and what it takes.
	local cards = {}
	if #tiers > 1 then
		local group = Create.new("Frame", {
			Name = "Tiers",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = card,
		})
		Create.list(group, "Horizontal", 8, { VerticalAlignment = Enum.VerticalAlignment.Top })
		for index, tier in tiers do
			local paid = paidRank ~= nil and index >= paidRank
			local ad = adService(tier)
			local tag = tier.Tag
			if not tag then
				tag = if tier.NoKey then Strings.get("No key needed") elseif ad then Strings.get("Via {service}", { service = ad.Name or Strings.get("an ad") }) elseif paid then Strings.get("Paid key") else Strings.get("Key required")
				if tier.Duration and showExpiry then
					tag ..= ` · {Env.duration(tier.Duration)}`
				end
			end
			local button = Create.new("TextButton", {
				Name = "Tier",
				Size = UDim2.new(0, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = index,
				Theme = { BackgroundColor3 = "raised" },
				Parent = group,
			}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
			Create.corner(10, button)
			Create.padding(button, 12, 10)
			Create.list(button, "Vertical", 4)
			local edge = Create.stroke("stroke", button, 1.5)
			local top = Create.new("Frame", { Name = "Top", Size = UDim2.new(1, 0, 0, 18), Parent = button })
			Create.list(top, "Horizontal", 6)
			Create.icon(tier.Icon or (if paid then "crown" elseif tier.NoKey then "lock-open" else "key"), 16, if paid then "warning" else "accent", top)
			Create.fit(Create.new("TextLabel", {
				Name = "Name",
				Size = UDim2.fromScale(0, 1),
				Text = tier.Name,
				Weight = "bold",
				TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = 1,
				Theme = { TextColor3 = "text" },
				Parent = top,
			}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) }), 10)
			local check = Create.new("Frame", {
				Name = "Check",
				Size = UDim2.fromOffset(16, 16),
				LayoutOrder = 2,
				Theme = { BackgroundColor3 = "accent" },
				Parent = top,
			})
			Create.corner(-1, check)
			local tick = Create.icon("check", 11, "onAccent", check)
			tick.AnchorPoint = Vector2.new(0.5, 0.5)
			tick.Position = UDim2.fromScale(0.5, 0.5)
			Create.new("TextLabel", {
				Name = "Tag",
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true,
				TextSize = 12,
				LayoutOrder = 1,
				Text = tag,
				Theme = { TextColor3 = "textMuted" },
				Parent = button,
			})
			cards[index] = { button = button, edge = edge, check = check }
		end
	end

	local description = Dialog.text(card, "", 3)
	description.TextSize = 12

	-- The key field: an icon, then the box, inside one outlined surface that
	-- lights up while it has focus.
	local field = Create.new("Frame", {
		Name = "Field",
		Size = UDim2.new(1, 0, 0, 46),
		LayoutOrder = 4,
		Theme = { BackgroundColor3 = "raised" },
		Parent = card,
	})
	Create.corner(10, field)
	local fieldEdge = Create.stroke("stroke", field, 1.5)
	local keyIcon = Create.icon("key-round", 16, "textMuted", field)
	keyIcon.AnchorPoint = Vector2.new(0, 0.5)
	keyIcon.Position = UDim2.new(0, 14, 0.5, 0)
	local input = Create.new("TextBox", {
		Name = "Key",
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -52, 1, 0),
		PlaceholderText = Strings.get("Paste your key"),
		TextSize = 14,
		ClipsDescendants = true,
		Theme = { TextColor3 = "text" },
		Parent = field,
	})
	scope:connect(input.Focused, function()
		Theme.bind(fieldEdge, "Color", "accent")
		Theme.bind(keyIcon, "ImageColor3", "accent")
	end)
	scope:connect(input.FocusLost, function()
		Theme.bind(fieldEdge, "Color", "stroke")
		Theme.bind(keyIcon, "ImageColor3", "textMuted")
	end)
	local status = Dialog.text(card, "", 5)
	status.TextSize = 12

	local actions = Create.new("Frame", { Name = "Actions", Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 6, Parent = card })
	Create.list(actions, "Horizontal", 8)
	local getKey = Dialog.button(scope, actions, { Name = "GetKey", Size = UDim2.fromScale(0, 1), LayoutOrder = 1, Effect = effect })
	Create.stroke("stroke", getKey)
	local verify = Dialog.button(scope, actions, {
		Name = "Verify",
		Variant = "Primary",
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
		Effect = effect,
	})
	for _, button in { getKey, verify } do
		Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = button })
	end

	-- Without a clipboard the link is shown in a box the player can select.
	local linkBox = Create.new("TextBox", {
		Name = "Link",
		Size = UDim2.new(1, 0, 0, 34),
		TextEditable = false,
		TextSize = 12,
		ClipsDescendants = true,
		Visible = false,
		LayoutOrder = 7,
		Theme = { BackgroundColor3 = "raised", TextColor3 = "text" },
		Parent = card,
	})
	Create.corner(8, linkBox)
	Create.padding(linkBox, 10, 0)

	-- A quiet line under everything: how long a key lasts and that it is kept.
	local footer = Dialog.text(card, "", 8)
	footer.TextSize = 12
	footer.TextXAlignment = Enum.TextXAlignment.Center

	local function setStatus(text, role)
		status.Text = text
		status.Visible = text ~= ""
		Theme.bind(status, "TextColor3", role or "textMuted")
	end

	-- Discord = "https://discord.gg/..." puts a round invite button under the
	-- prompt; false or nothing leaves it out.
	local discord = DiscordButton.settings(options.Discord)
	if discord then
		local line = Create.new("Frame", { Name = "Community", Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 9, Parent = card })
		Create.list(line, "Horizontal", 10, { HorizontalAlignment = Enum.HorizontalAlignment.Center })
		local settings = { Link = discord.Link, Icon = discord.Icon, Size = 36, LayoutOrder = 1, Label = discord.Label or Strings.get("Join the Discord") }
		DiscordButton.new(scope, line, settings, function(how, link)
			if how == "opened" then
				setStatus(Strings.get("Opened the invite in Discord."), "success")
			elseif how == "copied" then
				setStatus(Strings.get("Discord invite copied. Paste it into your browser."), "success")
			else
				linkBox.Text = link
				linkBox.Visible = true
				setStatus(Strings.get("Copy the invite from the box below."), "info")
			end
		end)
	end

	local function refresh()
		local tier = tiers[selected]
		-- Sentences that name the tier use its translated name, once known.
		tier = setmetatable({ Name = Translate.text(tier.Name) }, { __index = tier })
		-- The chosen card shows an accent outline, a light accent fill and a
		-- check, so the choice never rests on colour alone.
		for index, entry in cards do
			local on = index == selected
			Theme.bind(entry.edge, "Color", if on then "accent" else "stroke")
			Theme.bind(entry.button, "BackgroundColor3", if on then "accent" else "raised")
			entry.button.BackgroundTransparency = if on then 0.88 else 0
			entry.check.Visible = on
		end
		local ad = adService(tier)
		local service = if ad then ad.Name or "the ad" else nil
		local keyed = not (ad and ad.RequiresKey == false)
		local hint = tier.Description or (if ad then Strings.get("Finish the {service} step to unlock {tier}.", { service = service, tier = tier.Name }) else nil)
		description.Text = hint or ""
		description.Visible = hint ~= nil
		input.Visible = not tier.NoKey and keyed
		field.Visible = input.Visible
		local lasts = if tier.Duration and showExpiry and input.Visible then Strings.get("Keys for {tier} last {time}.", { tier = tier.Name, time = Env.duration(tier.Duration) }) else nil
		local kept = if options.SaveKey ~= false and input.Visible then Strings.get("Your key is saved on this device.") else nil
		footer.Text = if lasts and kept then `{lasts} {kept}` else lasts or kept or ""
		footer.Visible = footer.Text ~= ""
		getKey.Visible = not tier.NoKey and (tier.Link ~= nil or tier.GetLink ~= nil or (ad ~= nil and (ad.Link ~= nil or ad.GetLink ~= nil)))
		getKey.Text = tier.LinkLabel or (if ad then Strings.get("Open {service}", { service = service }) else Strings.get("Get a key"))
		verify.Text = if busy then Strings.get("Checking") elseif tier.NoKey then Strings.get("Continue with {tier}", { tier = tier.Name }) elseif not keyed then Strings.get("I finished {service}", { service = service }) else Strings.get("Verify key")
		linkBox.Visible = false
	end

	local function finish(index, key, detail)
		local duration = tiers[index].Duration
		outcome = access(index, key, false, detail, if duration and key then os.time() + duration else nil)
		if key and key ~= "" and options.SaveKey ~= false then
			local encoded, text = Env.encode({ version = VERSION, key = key, tier = names[index], savedAt = os.time() })
			outcome.Saved = encoded and Env.write(savedPath(context.folder), text) == true
		end
		Env.call("Key system", options.OnSuccess, outcome)
		shell.Close()
	end

	local function lockOut()
		locked = true
		scope:add(task.spawn(function()
			for remaining = cooldown, 1, -1 do
				setStatus(Strings.get("Too many attempts. Try again in {seconds} s.", { seconds = remaining }), "danger")
				task.wait(1)
			end
			locked, attempts = false, 0
			setStatus("", nil)
		end))
	end

	local function submit()
		if busy or locked then
			return
		end
		local tier = tiers[selected]
		if tier.NoKey then
			finish(selected, nil)
			return
		end
		local key = trim(input.Text)
		busy = true
		setStatus(Strings.get("Checking the key."), "textMuted")
		refresh()
		local index, message, detail = KeySystem.check(options, selected, key)
		busy = false
		if shell.Closed then
			return
		end
		refresh()
		if index then
			finish(index, key, detail)
			return
		end
		attempts += 1
		Env.call("Key system", options.OnFail, message)
		if attempts >= maxAttempts then
			lockOut()
		else
			setStatus(message, "danger")
			Motion.tween(input, "fast", { BackgroundColor3 = Theme.color("raised") })
		end
	end

	for index, entry in cards do
		scope:connect(entry.button.Activated, function()
			selected = index
			if not locked then
				setStatus("", nil)
			end
			refresh()
		end)
	end
	scope:connect(verify.Activated, submit)
	scope:connect(input.FocusLost, function(entered)
		if entered then
			submit()
		end
	end)
	scope:connect(getKey.Activated, function()
		local tier = tiers[selected]
		local ad = adService(tier)
		local link = (ad and ad.Link) or tier.Link
		local make = (ad and ad.GetLink) or tier.GetLink
		if type(make) == "function" then
			local ok, made = pcall(make)
			link = if ok then made else nil
		end
		if type(link) ~= "string" then
			setStatus(Strings.get("The key link is not available right now."), "danger")
		elseif Env.copy(link) then
			local sentence = if not ad
				then "Link copied. Open it in your browser to get a key."
				elseif ad.RequiresKey == false then "Link copied. Open it in your browser and finish the step, then confirm here."
				else "Link copied. Open it in your browser and finish the step, then paste your key here."
			setStatus(Strings.get(sentence), "success")
		else
			linkBox.Text = link
			linkBox.Visible = true
			setStatus(Strings.get("Copy this link and open it in your browser."), "textMuted")
		end
	end)

	setStatus("", nil)
	refresh()
	for _, tier in tiers do
		Translate.whenReady(tier.Name, function()
			if not done and verify.Parent then
				refresh()
			end
		end)
	end
	if not done then
		waiter = coroutine.running()
		coroutine.yield()
	end
	return outcome
end

return KeySystem
