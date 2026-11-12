-- A round button that hands the player the hub's Discord invite. Roblox
-- cannot open a browser, so a press copies the link and says so.

local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Icons = require("../Core/Icons")
local Motion = require("../Core/Motion")

-- Discord's own brand colour, the same in every theme.
local BLURPLE = Color3.fromRGB(88, 101, 242)

local DiscordButton = {}

-- Accepts an invite link, or a table { Link, Icon, Size }. Anything else
-- (false, nil) means no button.
function DiscordButton.settings(value)
	if type(value) == "string" and value ~= "" then
		return { Link = value }
	elseif type(value) == "table" and type(value.Link) == "string" then
		return value
	end
	return nil
end

-- Draws the button in `parent`. `report(copied, link)` tells the player
-- what happened, in whatever place suits the caller.
function DiscordButton.new(scope, parent, settings, report)
	local size = settings.Size or 32
	local button = Create.new("ImageButton", {
		Name = "Discord",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = BLURPLE,
		LayoutOrder = settings.LayoutOrder or 10,
		Parent = parent,
	})
	Create.corner(-1, button)
	local glyph = Create.new("ImageLabel", {
		Name = "Mark",
		Size = UDim2.fromOffset(math.floor(size * 0.5), math.floor(size * 0.5)),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ImageColor3 = Color3.new(1, 1, 1),
		Parent = button,
	})
	-- Any image works as the mark: an icon name, an asset id, a URL or a file.
	Icons.apply(glyph, settings.Icon or "message-circle")
	local scale = Create.new("UIScale", { Parent = button })
	scope:connect(button.MouseEnter, function()
		Motion.tween(scale, "spring", { Scale = 1.08 })
	end)
	scope:connect(button.MouseLeave, function()
		Motion.tween(scale, "spring", { Scale = 1 })
	end)
	scope:connect(button.Activated, function()
		local copied = Env.copy(settings.Link)
		report(copied, settings.Link)
	end)
	return button
end

return DiscordButton
