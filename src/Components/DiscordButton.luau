-- A round button that hands the player the hub's Discord invite. A press
-- asks the Discord app on this computer to open the invite; when no app is
-- listening, or there is no `request` to reach it with, it copies the link.

local HttpService = game:GetService("HttpService")

local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Icons = require("../Core/Icons")
local Motion = require("../Core/Motion")
local Theme = require("../Core/Theme")

-- Discord's own brand colour, the same in every theme.
local BLURPLE = Color3.fromRGB(88, 101, 242)
local BLURPLE_HOVER = Color3.fromRGB(116, 127, 247)
-- The white Discord logo on a clear background, a public Creator Store
-- decal (132364423955781) shown through its thumbnail.
local LOGO = "rbxthumb://type=Asset&id=132364423955781&w=150&h=150"
-- The desktop app listens for invites on the first free port in this range.
local FIRST_PORT, LAST_PORT = 6463, 6472

local DiscordButton = {}

-- Accepts an invite link, or a table { Link, Icon, Size, Label }. Anything
-- else (false, nil) means no button.
function DiscordButton.settings(value)
	if type(value) == "string" and value ~= "" then
		return { Link = value }
	elseif type(value) == "table" and type(value.Link) == "string" then
		return value
	end
	return nil
end

-- The invite code from discord.gg/code, discord.com/invite/code or a bare code.
function DiscordButton.code(link)
	if type(link) ~= "string" then
		return nil
	end
	return string.match(link, "discord%.gg/([%w%-]+)")
		or string.match(link, "discord%.com/invite/([%w%-]+)")
		or string.match(link, "discordapp%.com/invite/([%w%-]+)")
		or string.match(link, "^([%w%-]+)$")
end

-- Returns "opened" when the Discord app took the invite, "copied" when the
-- link went to the clipboard, or false when neither worked.
function DiscordButton.open(link)
	local code = DiscordButton.code(link)
	if code and Env.request then
		local body = HttpService:JSONEncode({
			cmd = "INVITE_BROWSER",
			args = { code = code },
			nonce = HttpService:GenerateGUID(false),
		})
		for port = FIRST_PORT, LAST_PORT do
			local ok, reply = Env.http({
				Url = `http://127.0.0.1:{port}/rpc?v=1`,
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json", Origin = "https://discord.com" },
				Body = body,
			})
			-- Discord can answer with an error event, such as for a dead invite.
			if ok and not string.find(tostring(reply), '"evt":"ERROR"', 1, true) then
				return "opened"
			end
		end
	end
	return if Env.copy(link) then "copied" else false
end

-- Draws the button in `parent`, with `settings.Label` as words beside it
-- that press the same way. `report(how, link)` tells the player what
-- happened ("opened", "copied" or false), in whatever place suits the caller.
function DiscordButton.new(scope, parent, settings, report)
	local size = settings.Size or 32
	local order = settings.LayoutOrder or 10
	local button = Create.new("ImageButton", {
		Name = "Discord",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = BLURPLE,
		LayoutOrder = order,
		Parent = parent,
	})
	Create.corner(-1, button)
	local glyph = Create.new("ImageLabel", {
		Name = "Mark",
		Size = UDim2.fromOffset(math.floor(size * 0.62), math.floor(size * 0.62)),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ImageColor3 = Color3.new(1, 1, 1),
		Parent = button,
	})
	-- The Discord logo unless the hub gives its own: an icon name, an asset
	-- id, a URL or a file.
	Icons.apply(glyph, settings.Icon or LOGO)
	local label
	if settings.Label then
		label = Create.new("TextButton", {
			Name = "Label",
			Size = UDim2.fromOffset(0, size),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = settings.Label,
			TextSize = 13,
			Weight = "medium",
			LayoutOrder = order + 1,
			Theme = { TextColor3 = "textMuted" },
			Parent = parent,
		})
	end

	-- Hover: the fill brightens, the logo lifts with a slight tilt and the
	-- words brighten. A press sinks the whole button.
	local scale = Create.new("UIScale", { Parent = button })
	local markScale = Create.new("UIScale", { Parent = glyph })
	local hovered = false
	local function settle()
		Motion.tween(button, "fast", { BackgroundColor3 = if hovered then BLURPLE_HOVER else BLURPLE })
		Motion.tween(markScale, "spring", { Scale = if hovered then 1.12 else 1 })
		Motion.tween(glyph, "spring", { Rotation = if hovered then -8 else 0 })
		Motion.tween(scale, "spring", { Scale = if hovered then 1.06 else 1 })
		if label then
			Theme.bind(label, "TextColor3", if hovered then "text" else "textMuted")
		end
	end
	-- One press at a time, since trying each port can take a moment.
	local busy = false
	local function press()
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local how = DiscordButton.open(settings.Link)
			busy = false
			report(how, settings.Link)
		end)
	end
	for _, target in { button, label } do
		scope:connect(target.MouseEnter, function()
			hovered = true
			settle()
		end)
		scope:connect(target.MouseLeave, function()
			hovered = false
			settle()
		end)
		scope:connect(target.MouseButton1Down, function()
			Motion.tween(scale, "fast", { Scale = 0.92 })
		end)
		scope:connect(target.MouseButton1Up, settle)
		scope:connect(target.Activated, press)
	end
	return button
end

return DiscordButton
