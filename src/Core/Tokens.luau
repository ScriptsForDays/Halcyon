-- The few numbers that set the library's overall feel: how round corners
-- are, how tightly rows pack, and how large text is. Components read these
-- when they build, so a window created after a change picks it up.

local RADIUS = {
	-- Square edges with a hint of softening; pills become small squares.
	Sharp = { scale = 0.25, pill = 3 },
	Soft = { scale = 0.6 },
	Default = { scale = 1 },
	Round = { scale = 1.4 },
}

local DENSITY = {
	Compact = { rowHeight = 36, rowPadding = 5, gap = 4, sectionPadding = 8 },
	Default = { rowHeight = 44, rowPadding = 8, gap = 6, sectionPadding = 10 },
	Spacious = { rowHeight = 52, rowPadding = 12, gap = 8, sectionPadding = 14 },
}

local TEXT = { Default = 1, Large = 1.15, Larger = 1.3 }

local Tokens = {
	Radius = { "Sharp", "Soft", "Default", "Round" },
	Density = { "Compact", "Default", "Spacious" },
	TextSize = { "Default", "Large", "Larger" },
	radius = RADIUS.Default,
	density = DENSITY.Default,
	textScale = 1,
	-- Touch rows never pack below the 44 px a finger needs.
	touch = false,
	names = { radius = "Default", density = "Default", text = "Default" },
}

-- Sets any of Radius, Density and TextSize from a table of names. Unknown
-- names are ignored so a typo keeps the default.
function Tokens.set(settings)
	if type(settings) ~= "table" then
		return
	end
	if RADIUS[settings.Radius] then
		Tokens.radius, Tokens.names.radius = RADIUS[settings.Radius], settings.Radius
	end
	if DENSITY[settings.Density] then
		Tokens.density, Tokens.names.density = DENSITY[settings.Density], settings.Density
	end
	if TEXT[settings.TextSize] then
		Tokens.textScale, Tokens.names.text = TEXT[settings.TextSize], settings.TextSize
	end
end

function Tokens.reset()
	Tokens.radius, Tokens.density, Tokens.textScale = RADIUS.Default, DENSITY.Default, 1
	Tokens.names = { radius = "Default", density = "Default", text = "Default" }
end

-- A corner radius after the Radius setting. -1 (fully round) stays round
-- unless the setting squares pills off.
function Tokens.corner(radius)
	if radius < 0 then
		return Tokens.radius.pill or -1
	end
	return math.round(radius * Tokens.radius.scale)
end

function Tokens.text(size)
	return math.round(size * Tokens.textScale)
end

function Tokens.rowHeight()
	local height = Tokens.density.rowHeight
	return if Tokens.touch then math.max(height, 44) else height
end

return Tokens
