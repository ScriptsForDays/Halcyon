-- Saved element values. Each flagged element is written through its own
-- Encode and read back through Decode, so colours and keys survive JSON.

local Env = require("./Env")
local Strings = require("./Strings")

local VERSION = 1
local INVALID_NAME_MESSAGE = "Use letters, numbers, spaces, - or _ in a config name."

local Config = {}
Config.__index = Config

-- With per-game configs, each game keeps its own folder and autoload under
-- configs/<id>/, and configs saved before that, straight in configs/, still
-- load and list.
function Config.new(folder, gameKey)
	local root = "Halcyon/" .. folder
	local shared = root .. "/configs"
	return setmetatable({
		root = root,
		shared = shared,
		folder = if gameKey then `{shared}/{gameKey}` else shared,
		autoloadPath = if gameKey then `{shared}/{gameKey}/autoload.txt` else root .. "/autoload.txt",
		flags = {},
	}, Config)
end

-- The folder name for this game from CreateWindow's `Configs` option:
-- { PerGame = "Place" } keys by place, "Universe" (or true) by experience,
-- so every place of one game shares configs.
function Config.gameKey(settings)
	local mode = type(settings) == "table" and settings.PerGame
	if mode == "Place" then
		return tostring(game.PlaceId or 0)
	elseif mode == "Universe" or mode == true then
		local universe = game.GameId
		return tostring(if universe and universe ~= 0 then universe else game.PlaceId or 0)
	end
	return nil
end

function Config:path(name)
	return `{self.folder}/{name}.json`
end

-- Where a config by this name is stored: this game's folder first, then the
-- shared one. Nil when there is none.
function Config:find(safe)
	for _, path in { self:path(safe), `{self.shared}/{safe}.json` } do
		if Env.read(path) then
			return path
		end
	end
	return nil
end

function Config:collect()
	local values = {}
	for flag, handle in self.flags do
		if handle.Get then
			local ok, value = pcall(function()
				return if handle.Encode then handle:Encode() else handle:Get()
			end)
			if ok then
				values[flag] = value
			end
		end
	end
	return values
end

-- Sets every flag the hub still has and skips the rest. Returns how many were set.
function Config:apply(values)
	local count = 0
	for flag, value in values do
		local handle = self.flags[flag]
		if handle and handle.Set then
			local ok, message = pcall(function()
				handle:Set(if handle.Decode then handle:Decode(value) else value)
			end)
			if ok then
				count += 1
			else
				warn(`[Halcyon] Config value for "{flag}" was skipped: {message}`)
			end
		end
	end
	return count
end

function Config:save(name)
	local safe = Env.safeName(name)
	if not safe then
		return false, Strings.get(INVALID_NAME_MESSAGE)
	end
	local encoded, text = Env.encode({ version = VERSION, flags = self:collect() })
	if not encoded then
		return false, Strings.get("The config could not be encoded.")
	end
	local wrote, message = Env.write(self:path(safe), text)
	if not wrote then
		return false, message
	end
	return true, Strings.get('Saved "{name}".', { name = safe })
end

function Config:load(name)
	local safe = Env.safeName(name)
	if not safe then
		return false, Strings.get(INVALID_NAME_MESSAGE)
	elseif not Env.canSave then
		return false, Strings.get(Env.NO_FILES)
	end
	local found = self:find(safe)
	local content = found and Env.read(found)
	if not content then
		return false, Strings.get('There is no config named "{name}".', { name = safe })
	end
	local decoded, saved = Env.decode(content)
	if not decoded or type(saved) ~= "table" or type(saved.flags) ~= "table" then
		return false, Strings.get('"{name}" is not a valid config file.', { name = safe })
	end
	return true, Strings.get('Loaded "{name}" ({count} settings).', { name = safe, count = self:apply(saved.flags) })
end

function Config:delete(name)
	local safe = Env.safeName(name)
	if not safe then
		return false, Strings.get(INVALID_NAME_MESSAGE)
	end
	local found = self:find(safe)
	if not found then
		return false, Strings.get('There is no config named "{name}".', { name = safe })
	elseif not Env.remove(found) then
		return false, Strings.get("This executor cannot delete files.")
	end
	if self:getAutoload() == safe then
		self:setAutoload(nil)
	end
	return true, Strings.get('Deleted "{name}".', { name = safe })
end

function Config:exists(name)
	local safe = Env.safeName(name)
	return safe ~= nil and self:find(safe) ~= nil
end

function Config:list()
	local names = {}
	local folders = { self.folder }
	if self.folder ~= self.shared then
		table.insert(folders, self.shared)
	end
	for _, folder in folders do
		for _, file in Env.list(folder) do
			local name = string.match(file, "^(.+)%.json$")
			if name and not table.find(names, name) then
				table.insert(names, name)
			end
		end
	end
	return names
end

function Config:getAutoload()
	local name = Env.read(self.autoloadPath)
	return if name and name ~= "" then name else nil
end

function Config:setAutoload(name)
	local safe = if name then Env.safeName(name) else ""
	if not safe then
		return false, Strings.get(INVALID_NAME_MESSAGE)
	end
	local wrote, message = Env.write(self.autoloadPath, safe)
	if not wrote then
		return false, message
	end
	return true, if safe == "" then Strings.get("Autoload is off.") else Strings.get('"{name}" loads on start.', { name = safe })
end

return Config
