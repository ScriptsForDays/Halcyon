-- What the host can do. Executor functions are looked up once; anything that
-- is missing is reported to the caller, never papered over.

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local function optional(value)
	return if type(value) == "function" then value else nil
end

local Env = {
	writefile = optional(writefile),
	readfile = optional(readfile),
	isfile = optional(isfile),
	isfolder = optional(isfolder),
	makefolder = optional(makefolder),
	delfile = optional(delfile),
	listfiles = optional(listfiles),
	setclipboard = optional(setclipboard),
	identifyexecutor = optional(identifyexecutor),
	request = optional(request),
	getgenv = optional(getgenv),
	gethui = optional(gethui),
	NO_FILES = "This executor has no file functions, so nothing can be saved.",
	NO_HTTP = "HTTP requests are not available here.",
}

Env.canSave = Env.writefile ~= nil and Env.readfile ~= nil and Env.isfile ~= nil and Env.isfolder ~= nil and Env.makefolder ~= nil

function Env.executor()
	if Env.identifyexecutor then
		local ok, name, version = pcall(Env.identifyexecutor)
		if ok and type(name) == "string" and name ~= "" then
			return name, if type(version) == "string" then version else nil
		end
	end
	return if RunService:IsStudio() then "Roblox Studio" else "Unknown executor", nil
end

-- Scripts loaded separately share this table, which is how a second run finds the first.
function Env.globals()
	return if Env.getgenv then Env.getgenv() else _G
end

function Env.copy(text)
	if not Env.setclipboard then
		return false
	end
	return (pcall(Env.setclipboard, text))
end

-- File and folder names come from hub code and from players typing a config
-- name, so anything that could leave the Halcyon folder is stripped.
function Env.safeName(name)
	if type(name) ~= "string" then
		return nil
	end
	local safe = string.gsub(name, "[^%w _%-]", "")
	safe = string.sub(string.match(safe, "^%s*(.-)%s*$"), 1, 40)
	return if safe == "" then nil else safe
end

local function ensureFolder(path)
	local built = ""
	for _, part in string.split(path, "/") do
		built = if built == "" then part else built .. "/" .. part
		if not Env.isfolder(built) then
			Env.makefolder(built)
		end
	end
end

function Env.write(path, content)
	if not Env.canSave then
		return false, Env.NO_FILES
	end
	local ok, message = pcall(function()
		ensureFolder(string.match(path, "^(.*)/[^/]+$"))
		Env.writefile(path, content)
	end)
	return ok, if ok then nil else `Writing {path} failed: {message}`
end

function Env.read(path)
	if not Env.canSave then
		return nil
	end
	local ok, content = pcall(function()
		return if Env.isfile(path) then Env.readfile(path) else nil
	end)
	return if ok and type(content) == "string" then content else nil
end

function Env.remove(path)
	if not Env.delfile then
		return false
	end
	return (pcall(Env.delfile, path))
end

-- File names directly inside a folder, without the folder part.
function Env.list(folder)
	local names = {}
	if not (Env.canSave and Env.listfiles) then
		return names
	end
	local ok, paths = pcall(function()
		return if Env.isfolder(folder) then Env.listfiles(folder) else {}
	end)
	if ok and type(paths) == "table" then
		for _, path in paths do
			table.insert(names, string.match(path, "[^/\\]+$"))
		end
		table.sort(names)
	end
	return names
end

function Env.encode(value)
	return pcall(HttpService.JSONEncode, HttpService, value)
end

function Env.decode(text)
	return pcall(HttpService.JSONDecode, HttpService, text)
end

-- Returns ok, body, status. `request` is used when the executor has it;
-- otherwise only a plain GET is possible.
function Env.http(options)
	local method = options.Method or "GET"
	if Env.request then
		local ok, response = pcall(Env.request, { Url = options.Url, Method = method, Headers = options.Headers, Body = options.Body })
		if not ok or type(response) ~= "table" then
			return false, tostring(response), 0
		end
		local status = tonumber(response.StatusCode) or 0
		return status >= 200 and status < 300, response.Body or "", status
	end
	if method == "GET" then
		local ok, body = pcall(function()
			return game:HttpGet(options.Url)
		end)
		if ok and type(body) == "string" then
			return true, body, 200
		end
	end
	return false, Env.NO_HTTP, 0
end

-- Whether the executor provides `name`, such as "hookfunction" or
-- "Drawing.new". Names are checked against a strict pattern before any
-- lookup, so a dotted path is only ever walked, never run as code.
function Env.has(name)
	if type(name) ~= "string" or not string.match(name, "^[%a_][%w_]*%.?[%w_]*$") then
		return false
	end
	local parts = string.split(name, ".")
	local function walk(root)
		local value = root
		for _, part in parts do
			if type(value) ~= "table" then
				return nil
			end
			local ok, found = pcall(function()
				return value[part]
			end)
			value = if ok then found else nil
		end
		return value
	end
	if Env.getgenv and walk(Env.getgenv()) ~= nil then
		return true
	end
	-- Most executors keep their functions in the script's own environment,
	-- which plain Luau cannot index by name; a one-line chunk can.
	local compile = optional(loadstring)
	if compile then
		local ok, chunk = pcall(compile, "return " .. name)
		if ok and chunk then
			local found, value = pcall(chunk)
			return found and value ~= nil
		end
	end
	return false
end

-- The names in `names` that the executor lacks, in the order given.
function Env.missing(names)
	local absent = {}
	for _, name in names do
		if not Env.has(name) then
			table.insert(absent, name)
		end
	end
	return absent
end

-- A length of time as people say it: "2d 4h", "3h 12m", "45m", "30s".
function Env.duration(seconds)
	seconds = math.max(math.floor(seconds), 0)
	local days, hours = seconds // 86400, seconds // 3600 % 24
	local minutes = seconds // 60 % 60
	if days > 0 then
		return if hours > 0 then `{days}d {hours}h` else `{days}d`
	elseif hours > 0 then
		return if minutes > 0 then `{hours}h {minutes}m` else `{hours}h`
	elseif minutes > 0 then
		return `{minutes}m`
	end
	return `{seconds}s`
end

-- Runs hub code in its own thread so an error or a yield inside it cannot break the UI.
function Env.call(label, callback, ...)
	if type(callback) ~= "function" then
		return
	end
	task.spawn(function(...)
		local ok, message = pcall(callback, ...)
		if not ok then
			warn(`[Halcyon] {label} callback failed: {message}`)
		end
	end, ...)
end

return Env
