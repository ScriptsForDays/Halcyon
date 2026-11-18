-- Colours are roles, not values. An instance property is bound to a role, so
-- switching the palette recolours everything already on screen.

local Signal = require("./Signal")
local Schema = require("./Schema")

local ROLES = {
	"background",
	"surface",
	"card",
	"raised",
	"hover",
	"stroke",
	"text",
	"textMuted",
	"accent",
	"accentHover",
	"onAccent",
	"focus",
	"success",
	"warning",
	"danger",
	"info",
}
local TEXT_SURFACES = { "background", "surface", "card", "raised" }
local READABLE, UNREADABLE = 4.5, 3

local Theme = {
	Roles = ROLES,
	Changed = Signal.new(),
	GradientChanged = Signal.new(),
	palettes = {},
	order = {},
	current = nil,
	accent = nil,
	generation = 0,
	bindings = {},
}

local function channel(value)
	return if value <= 0.03928 then value / 12.92 else ((value + 0.055) / 1.055) ^ 2.4
end

local function luminance(color)
	return 0.2126 * channel(color.R) + 0.7152 * channel(color.G) + 0.0722 * channel(color.B)
end

-- WCAG contrast ratio between two colours, from 1 to 21.
function Theme.contrast(first, second)
	local a, b = luminance(first), luminance(second)
	return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05)
end

-- The lowest contrast any text role has on a surface it is drawn on.
function Theme.worstContrast(palette)
	local worst, pair = math.huge, ""
	local function consider(text, surface)
		local ratio = Theme.contrast(palette[text], palette[surface])
		if ratio < worst then
			worst, pair = ratio, text .. " on " .. surface
		end
	end
	for _, surface in TEXT_SURFACES do
		consider("text", surface)
		consider("textMuted", surface)
	end
	consider("onAccent", "accent")
	return worst, pair
end

-- Registers a palette. A table with `Base` inherits every role it leaves out.
-- Returns ok and a message: an error when refused, a warning when contrast is low.
function Theme.add(definition)
	if type(definition) ~= "table" or type(definition.Name) ~= "string" or definition.Name == "" then
		return false, "A theme needs a Name."
	end
	local base = if definition.Base then Theme.palettes[definition.Base] else nil
	if definition.Base and not base then
		return false, `Base theme "{definition.Base}" does not exist.`
	end

	local palette = { Name = definition.Name }
	for _, role in ROLES do
		local color = definition[role] or (base and base[role])
		if typeof(color) ~= "Color3" then
			return false, `Theme "{definition.Name}" is missing the "{role}" colour.`
		end
		palette[role] = color
	end

	local worst, pair = Theme.worstContrast(palette)
	if worst < UNREADABLE then
		return false, string.format('Theme "%s" is unreadable: %s has a contrast of %.1f.', definition.Name, pair, worst)
	end

	if not Theme.palettes[palette.Name] then
		table.insert(Theme.order, palette.Name)
	end
	Theme.palettes[palette.Name] = palette
	if Theme.current and Theme.current.Name == palette.Name then
		Theme.set(palette.Name)
	end
	if worst < READABLE then
		return true, string.format("%s has a contrast of %.1f; 4.5 or more is easier to read.", pair, worst)
	end
	return true, nil
end

function Theme.names()
	return table.clone(Theme.order)
end

function Theme.color(role)
	return Theme.current[role]
end

-- An accent override is laid over whichever palette is active, so it
-- survives a theme switch and never alters the registered palettes.
local function withAccent(palette, color)
	local hue, saturation, value = color:ToHSV()
	local tinted = table.clone(palette)
	tinted.accent = color
	tinted.accentHover = Color3.fromHSV(hue, saturation * 0.85, math.min(value * 1.12, 1))
	tinted.focus = tinted.accentHover
	tinted.onAccent = if luminance(color) > 0.35 then Color3.fromRGB(12, 14, 18) else Color3.new(1, 1, 1)
	return tinted
end

-- Status colours that stay apart for the common kinds of colour blindness:
-- blue for success, vermilion for danger, yellow for warning, purple for info.
local SAFE_STATUS = {
	success = Color3.fromHex("56B4E9"),
	warning = Color3.fromHex("F0E442"),
	danger = Color3.fromHex("E66100"),
	info = Color3.fromHex("CC79A7"),
}
local SAFE_STATUS_LIGHT = {
	success = Color3.fromHex("0072B2"),
	warning = Color3.fromHex("8A6D00"),
	danger = Color3.fromHex("B34700"),
	info = Color3.fromHex("8E3E73"),
}

function Theme.set(name)
	local palette = Theme.palettes[name]
	if not palette then
		Schema.warn(`Theme "{name}" does not exist; the theme stays {Theme.current and Theme.current.Name or "as it was"}.`)
		return false, `Theme "{name}" does not exist.`
	end
	if Theme.accent then
		palette = withAccent(palette, Theme.accent)
	end
	if Theme.safeStatus then
		palette = table.clone(palette)
		local light = luminance(palette.background) > 0.5
		for role, color in if light then SAFE_STATUS_LIGHT else SAFE_STATUS do
			palette[role] = color
		end
	end
	Theme.current = palette
	local function apply()
		for instance, properties in Theme.bindings do
			for property, role in properties do
				instance[property] = Theme.current[role]
			end
		end
	end
	apply()
	-- A colour tween that started before the switch writes its old target
	-- when it finishes, so the colours are applied again once every tween
	-- (0.35 s at most) has run out.
	Theme.generation += 1
	local generation = Theme.generation
	task.delay(0.4, function()
		if Theme.generation == generation then
			apply()
		end
	end)
	Theme.Changed:Fire(name)
	return true, nil
end

-- Swaps the status colours for ones that stay apart with colour blindness.
function Theme.setSafeStatus(enabled)
	Theme.safeStatus = enabled == true
	return Theme.set(Theme.current.Name)
end

-- A second accent colour that accent fills run into, or nil for flat
-- fills. true picks one a little further round the colour wheel.
function Theme.setGradient(color)
	if color == true then
		Theme.gradientAuto, Theme.gradient = true, nil
	else
		Theme.gradientAuto = false
		Theme.gradient = if typeof(color) == "Color3" then color else nil
	end
	Theme.GradientChanged:Fire()
end

-- The colour accent fills run into, or nil.
function Theme.gradientEnd()
	if Theme.gradient then
		return Theme.gradient
	elseif Theme.gradientAuto then
		local hue, saturation, value = Theme.current.accent:ToHSV()
		return Color3.fromHSV((hue + 0.11) % 1, saturation, value)
	end
	return nil
end

-- Pass nil to go back to the theme's own accent.
function Theme.setAccent(color)
	Theme.accent = if typeof(color) == "Color3" then color else nil
	return Theme.set(Theme.current.Name)
end

-- With `deferred`, the caller is animating to the colour itself and the
-- binding only takes over on the next theme change.
function Theme.bind(instance, property, role, deferred)
	local properties = Theme.bindings[instance]
	if not properties then
		properties = {}
		Theme.bindings[instance] = properties
		-- Instances are held strongly and released here; a weak table can drop
		-- one that is still on screen.
		instance.Destroying:Once(function()
			Theme.bindings[instance] = nil
		end)
	end
	properties[property] = role
	if not deferred then
		instance[property] = Theme.current[role]
	end
end

-- Stops following the palette, for a property given a fixed colour.
function Theme.unbind(instance, property)
	local properties = Theme.bindings[instance]
	if properties then
		properties[property] = nil
	end
end

-- Binds a role name, or sets a fixed Color3 and stops following the palette.
function Theme.paint(instance, property, value)
	if typeof(value) == "Color3" then
		Theme.unbind(instance, property)
		instance[property] = value
	elseif type(value) == "string" and Theme.current[value] ~= nil then
		Theme.bind(instance, property, value)
	end
end

return Theme
