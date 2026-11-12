-- Icons by name. A core Lucide set ships inside the bundle; the full packs
-- load on first use from Footagesus/Icons (MIT), pinned to one commit.
--
-- Pack files are read as data with patterns. They are never run, so a changed
-- upstream file cannot execute code here.

local Assets = require("./Assets")
local Env = require("./Env")
local IconData = require("./IconData")

local SOURCE = "https://raw.githubusercontent.com/Footagesus/Icons/46d30c19ba7bc601d6ec794a48dc3a89568b1eec/%s/dist/Icons.lua"
local CACHE = "Halcyon/cache/icons"
local DOWNLOADABLE = { lucide = true, solar = true, geist = true, craft = true, gravity = true, sfsymbols = true }
local FLAT = '%["([^"]+)"%]%s*=%s*"(rbxassetid://%d+)"'
local SHEET = '%["(%d+)"%]%s*=%s*"(rbxassetid://%d+)"'
local ENTRY = '%[?"?([%w%-_]+)"?%]?%s*=%s*(%b{})'
local POINT = "%s*=%s*Vector2%.new%((%d+),%s*(%d+)%)"

local Icons = {
	default = "lucide",
	packs = { lucide = { icons = table.clone(IconData), complete = false } },
	waiting = {},
	failed = {},
}

function Icons.parse(source)
	local icons, count = {}, 0
	if string.find(source, "Spritesheets", 1, true) then
		local sheets = {}
		for index, asset in string.gmatch(source, SHEET) do
			sheets[index] = asset
		end
		-- Packs list an icon's fields in different orders, so each entry is
		-- cut out whole and its fields are read one by one.
		local body = string.match(source, "Icons%s*=%s*(%b{})")
		for name, entry in string.gmatch(if body then string.sub(body, 2, -2) else "", ENTRY) do
			local sheet = sheets[string.match(entry, "Image%s*=%s*(%d+)") or ""]
			local x, y = string.match(entry, "ImageRectPosition" .. POINT)
			local width, height = string.match(entry, "ImageRectSize" .. POINT)
			if sheet and x and width then
				icons[name] = {
					Image = sheet,
					RectOffset = Vector2.new(tonumber(x), tonumber(y)),
					RectSize = Vector2.new(tonumber(width), tonumber(height)),
				}
				count += 1
			end
		end
	else
		for name, asset in string.gmatch(source, FLAT) do
			icons[name] = asset
			count += 1
		end
	end
	return if count > 0 then icons else nil
end

-- Returns the icon, or nil and the name of a pack that still has to load.
function Icons.resolve(name)
	if type(name) == "number" then
		return { Image = "rbxassetid://" .. name }
	elseif type(name) ~= "string" or name == "" then
		return nil
	elseif string.find(name, "^rbx") then
		return { Image = name }
	end

	local packName, iconName = string.match(name, "^([%w_]+):(.+)$")
	if not packName then
		packName, iconName = Icons.default, name
	end
	local pack = Icons.packs[packName]
	local entry = pack and pack.icons[iconName]
	if entry then
		return if type(entry) == "table" then entry else { Image = entry }
	end
	if DOWNLOADABLE[packName] and not (pack and pack.complete) and not Icons.failed[packName] then
		return nil, packName
	end
	return nil
end

function Icons.load(packName, callback)
	local waiting = Icons.waiting[packName]
	if waiting then
		table.insert(waiting, callback)
		return
	end
	waiting = { callback }
	Icons.waiting[packName] = waiting

	task.spawn(function()
		local path = `{CACHE}/{packName}.lua`
		local cached = Env.read(path)
		local parsed = cached and Icons.parse(cached)
		if not parsed then
			local ok, body = Env.http({ Url = string.format(SOURCE, packName) })
			parsed = if ok then Icons.parse(body) else nil
			if parsed then
				Env.write(path, body)
			end
		end

		Icons.waiting[packName] = nil
		if parsed then
			local pack = Icons.packs[packName] or { icons = {} }
			for name, entry in parsed do
				pack.icons[name] = entry
			end
			pack.complete = true
			Icons.packs[packName] = pack
		else
			Icons.failed[packName] = true
			warn(`[Halcyon] Icon pack "{packName}" could not be loaded; icons outside the built-in set stay blank.`)
		end
		for _, waiter in waiting do
			waiter(parsed ~= nil)
		end
	end)
end

local function show(image, icon)
	image.Image = icon.Image
	image.ImageRectOffset = icon.RectOffset or Vector2.zero
	image.ImageRectSize = icon.RectSize or Vector2.zero
end

-- Draws `name` on an ImageLabel now, or once its pack has loaded. The label
-- remembers the name it wants, so a late pack never overwrites a newer icon.
function Icons.apply(image, name)
	local wanted = tostring(name)
	image:SetAttribute("HalcyonIcon", wanted)
	-- A URL or workspace file is the hub's own picture, loaded through
	-- getcustomasset; a fallback icon stands in until or unless it loads.
	local kind = Assets.kind(name)
	if kind == "url" or kind == "file" then
		-- Cleared first: the load can finish before resolve returns.
		image.Image = ""
		local id = Assets.resolve(name, function(loaded)
			if image:GetAttribute("HalcyonIcon") ~= wanted then
				return
			end
			if loaded then
				show(image, { Image = loaded })
			else
				local fallback = Icons.resolve("image")
				if fallback then
					show(image, fallback)
				end
			end
		end)
		if id then
			show(image, { Image = id })
			return true
		end
		return false
	end
	local icon, pending = Icons.resolve(name)
	if icon then
		show(image, icon)
		return true
	end
	image.Image = ""
	if pending then
		Icons.load(pending, function(ok)
			local loaded = ok and image:GetAttribute("HalcyonIcon") == wanted and Icons.resolve(name)
			if loaded then
				show(image, loaded)
			end
		end)
	end
	return false
end

-- Registers a custom pack: a table of names to asset ids, content strings or
-- { Image, RectOffset, RectSize } sprites.
function Icons.addPack(packName, icons)
	if type(packName) ~= "string" or not string.find(packName, "^[%w_]+$") then
		return false, "An icon pack name may only use letters, numbers and _."
	elseif type(icons) ~= "table" then
		return false, "An icon pack is a table of names to asset ids."
	end
	local pack = { icons = {}, complete = true }
	for name, entry in icons do
		pack.icons[name] = if type(entry) == "number" then "rbxassetid://" .. entry else entry
	end
	Icons.packs[packName] = pack
	return true, nil
end

function Icons.setDefault(packName)
	if not (Icons.packs[packName] or DOWNLOADABLE[packName]) then
		return false, `Icon pack "{packName}" does not exist.`
	end
	Icons.default = packName
	return true, nil
end

return Icons
