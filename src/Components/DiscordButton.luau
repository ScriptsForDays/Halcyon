-- A round button that hands the player the hub's Discord invite. Roblox
-- cannot open a browser, so a press copies the link and says so.

local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Icons = require("../Core/Icons")
local Motion = require("../Core/Motion")

-- Discord's own brand colour, the same in every theme.
local BLURPLE = Color3.fromRGB(88, 101, 242)
local BLURPLE_HOVER = Color3.fromRGB(116, 127, 247)
-- The white Discord logo on a clear background, a public Creator Store
-- decal (132364423955781) shown through its thumbnail.
local LOGO = "rbxthumb://type=Asset&id=132364423955781&w=150&h=150"

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
		Size = UDim2.fromOffset(math.floor(size * 0.62), math.floor(size * 0.62)),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ImageColor3 = Color3.new(1, 1, 1),
		Parent = button,
	})
	-- The Discord logo unless the hub gives its own: an icon name, an asset
	-- id, a URL or a file.
	Icons.apply(glyph, settings.Icon or LOGO)
	-- Hover: the fill brightens, a soft ring spreads out from the edge and
	-- the logo lifts with a slight tilt. A press sinks the whole button.
	local scale = Create.new("UIScale", { Parent = button })
	local markScale = Create.new("UIScale", { Parent = glyph })
	local halo = Create.new("UIStroke", { Thickness = 0, Transparency = 1, Color = BLURPLE, Parent = button })
	local hovered = false
	local function settle()
		Motion.tween(button, "fast", { BackgroundColor3 = if hovered then BLURPLE_HOVER else BLURPLE })
		Motion.tween(halo, "base", { Thickness = if hovered then 4 else 0, Transparency = if hovered then 0.55 else 1 })
		Motion.tween(markScale, "spring", { Scale = if hovered then 1.12 else 1 })
		Motion.tween(glyph, "spring", { Rotation = if hovered then -8 else 0 })
		Motion.tween(scale, "spring", { Scale = if hovered then 1.06 else 1 })
	end
	scope:connect(button.MouseEnter, function()
		hovered = true
		settle()
	end)
	scope:connect(button.MouseLeave, function()
		hovered = false
		settle()
	end)
	scope:connect(button.MouseButton1Down, function()
		Motion.tween(scale, "fast", { Scale = 0.92 })
	end)
	scope:connect(button.MouseButton1Up, settle)
	scope:connect(button.Activated, function()
		local copied = Env.copy(settings.Link)
		report(copied, settings.Link)
	end)
	return button
end

return DiscordButton
