-- Images the hub brings itself: a URL or a file in the executor's
-- workspace, turned into something an ImageLabel can show through
-- getcustomasset. Roblox asset ids pass straight through.
--
--   Assets.resolve("https://example.com/logo.png", function(id) ... end)
--
-- Downloads are cached on disk under Halcyon/assets, so a hub that runs
-- again shows its images without fetching them twice.

local Env = require("./Env")

local FOLDER = "Halcyon/assets"
-- Larger than any sensible UI image; stops a wrong URL filling the disk.
local MAX_BYTES = 5 * 1024 * 1024
local EXTENSIONS = { png = true, jpg = true, jpeg = true, bmp = true, tga = true }

local Assets = { ids = {}, waiting = {}, MAX_BYTES = MAX_BYTES }

local getAsset = Env.getcustomasset

-- "asset" for ids Roblox can show directly, "url" for web images, "file"
-- for a workspace path, or nil when it is none of these (an icon name).
function Assets.kind(source)
	if type(source) == "number" then
		return "asset"
	elseif type(source) ~= "string" or source == "" then
		return nil
	elseif string.find(source, "^rbx") then
		return "asset"
	elseif string.find(source, "^https?://") then
		return "url"
	elseif string.find(source, "://", 1, true) then
		return nil
	elseif string.find(source, "%.%a+$") and EXTENSIONS[string.lower(string.match(source, "%.(%a+)$"))] then
		return "file"
	end
	return nil
end

-- A workspace path is accepted only when it stays inside the workspace:
-- no parent steps, no absolute or drive paths, plain characters only.
function Assets.safePath(path)
	if type(path) ~= "string" or string.find(path, "%.%.") or string.find(path, "^[/\\]") or string.find(path, "^%a:") then
		return nil
	end
	if not string.match(path, "^[%w _%-%./]+$") then
		return nil
	end
	return path
end

-- A short, stable file name for a URL, keeping its image extension.
function Assets.cachePath(url)
	local hash = 5381
	for index = 1, #url do
		hash = (hash * 33 + string.byte(url, index)) % 4294967296
	end
	local extension = string.match(string.match(url, "^[^?#]*") or url, "%.(%a+)$")
	extension = if extension and EXTENSIONS[string.lower(extension)] then string.lower(extension) else "png"
	return string.format("%s/%08x.%s", FOLDER, hash, extension)
end

local function fromFile(path)
	if not getAsset then
		return nil, "This executor cannot show custom images (no getcustomasset)."
	end
	local ok, id = pcall(getAsset, path)
	if ok and type(id) == "string" and id ~= "" then
		return id, nil
	end
	return nil, `Could not load {path} as an image.`
end

local function download(url)
	if not getAsset then
		return nil, "This executor cannot show custom images (no getcustomasset)."
	elseif not Env.canSave then
		return nil, Env.NO_FILES
	end
	local path = Assets.cachePath(url)
	if Env.isfile(path) then
		return fromFile(path)
	end
	local ok, body = Env.http({ Url = url })
	if not ok or type(body) ~= "string" or body == "" then
		return nil, `Could not download {url}.`
	elseif #body > MAX_BYTES then
		return nil, "That image is larger than 5 MB."
	end
	local wrote, problem = Env.write(path, body)
	if not wrote then
		return nil, problem
	end
	return fromFile(path)
end

-- Returns the id now when it is known. Otherwise starts loading it, returns
-- nil, and calls `callback(id, problem)` once finished; `problem` explains a
-- failure in words a player can read.
function Assets.resolve(source, callback)
	local kind = Assets.kind(source)
	if kind == "asset" then
		return if type(source) == "number" then "rbxassetid://" .. source else source
	elseif kind == nil then
		if callback then
			callback(nil, "That is not an image id, URL or file.")
		end
		return nil
	end
	local key = tostring(source)
	if Assets.ids[key] then
		return Assets.ids[key]
	end
	if kind == "file" and not Assets.safePath(key) then
		if callback then
			callback(nil, "Image files must be inside the workspace.")
		end
		return nil
	end
	-- One download per URL however many labels ask for it at once.
	local waiting = Assets.waiting[key]
	if waiting then
		if callback then
			table.insert(waiting, callback)
		end
		return nil
	end
	waiting = { callback }
	Assets.waiting[key] = waiting
	task.spawn(function()
		local id, problem
		if kind == "url" then
			id, problem = download(key)
		else
			id, problem = fromFile(key)
		end
		Assets.ids[key] = id
		Assets.waiting[key] = nil
		for _, waiter in waiting do
			waiter(id, problem)
		end
	end)
	return nil
end

-- Forgets what was loaded, so tests and reloads start clean.
function Assets.reset()
	table.clear(Assets.ids)
	table.clear(Assets.waiting)
	getAsset = Env.getcustomasset
end

return Assets
