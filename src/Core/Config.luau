-- Saved element values. Each flagged element is written through its own
-- Encode and read back through Decode, so colours and keys survive JSON.

local Env = require("./Env")

local VERSION = 1
local INVALID_NAME_MESSAGE = "Use letters, numbers, spaces, - or _ in a config name."

local Config = {}
Config.__index = Config

function Config.new(folder)
	return setmetatable({ root = "Halcyon/" .. folder, flags = {} }, Config)
end

function Config:path(name)
	return `{self.root}/configs/{name}.json`
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
		return false, INVALID_NAME_MESSAGE
	end
	local encoded, text = Env.encode({ version = VERSION, flags = self:collect() })
	if not encoded then
		return false, "The config could not be encoded."
	end
	local wrote, message = Env.write(self:path(safe), text)
	if not wrote then
		return false, message
	end
	return true, `Saved "{safe}".`
end

function Config:load(name)
	local safe = Env.safeName(name)
	if not safe then
		return false, INVALID_NAME_MESSAGE
	elseif not Env.canSave then
		return false, Env.NO_FILES
	end
	local content = Env.read(self:path(safe))
	if not content then
		return false, `There is no config named "{safe}".`
	end
	local decoded, saved = Env.decode(content)
	if not decoded or type(saved) ~= "table" or type(saved.flags) ~= "table" then
		return false, `"{safe}" is not a valid config file.`
	end
	return true, `Loaded "{safe}" ({self:apply(saved.flags)} settings).`
end

function Config:delete(name)
	local safe = Env.safeName(name)
	if not safe then
		return false, INVALID_NAME_MESSAGE
	elseif not Env.read(self:path(safe)) then
		return false, `There is no config named "{safe}".`
	elseif not Env.remove(self:path(safe)) then
		return false, "This executor cannot delete files."
	end
	if self:getAutoload() == safe then
		self:setAutoload(nil)
	end
	return true, `Deleted "{safe}".`
end

function Config:exists(name)
	local safe = Env.safeName(name)
	return safe ~= nil and Env.read(self:path(safe)) ~= nil
end

function Config:list()
	local names = {}
	for _, file in Env.list(self.root .. "/configs") do
		local name = string.match(file, "^(.+)%.json$")
		if name then
			table.insert(names, name)
		end
	end
	return names
end

function Config:getAutoload()
	local name = Env.read(self.root .. "/autoload.txt")
	return if name and name ~= "" then name else nil
end

function Config:setAutoload(name)
	local safe = if name then Env.safeName(name) else ""
	if not safe then
		return false, INVALID_NAME_MESSAGE
	end
	local wrote, message = Env.write(self.root .. "/autoload.txt", safe)
	if not wrote then
		return false, message
	end
	return true, if safe == "" then "Autoload is off." else `"{safe}" loads on start.`
end

return Config
