-- Halcyon:Build: a whole hub from one table. The same calls a hub would
-- make by hand, driven by data, so a spec is easy to write, read and check.
-- Mistakes are reported with where they are in the spec:
--   Tabs[2].Sections[1].Elements[3]: unknown kind "Togle", did you mean "Toggle"?
--
--   Halcyon:Build({
--       Window = { Title = "Farm Hub", Folder = "FarmHub" },
--       Tabs = {
--           { Title = "Farm", Icon = "sprout", Sections = {
--               { Title = "Auto", Elements = {
--                   { "Toggle", Title = "Auto farm", Flag = "AutoFarm", Callback = function(on) end },
--               } },
--           } },
--       },
--       SettingsTab = true,
--   })

local Registry = require("../Elements/Registry")
local Schema = require("../Core/Schema")

local Build = {}

-- Keys that shape the spec rather than being options of what they sit on.
local STRUCTURE = { Sections = true, Elements = true, Pages = true, Kind = true, Id = true }

local function optionsOf(spec)
	local options = {}
	for key, value in spec do
		if type(key) == "string" and not STRUCTURE[key] then
			options[key] = value
		end
	end
	return options
end

local function fail(path, message)
	error(`Halcyon:Build {path}: {message}`, 0)
end

local function call(path, target, method, options)
	local ok, result = pcall(target[method], target, options)
	if not ok then
		fail(path, tostring(result))
	end
	return result
end

function Build.run(Halcyon, spec)
	if type(spec) ~= "table" then
		error("Halcyon:Build expects a table", 3)
	end
	local window = Halcyon:CreateWindow(spec.Window or {})
	if not window then
		return nil, {}
	end
	-- Elements by Id or Flag, for the hub to reach after building.
	local elements = {}

	local function addElements(container, list, path)
		if list == nil then
			return
		end
		if type(list) ~= "table" then
			fail(path, "Elements must be a list")
		end
		for index, item in list do
			local where = `{path}.Elements[{index}]`
			if type(item) ~= "table" then
				fail(where, "each element is a table such as { \"Toggle\", Title = \"Fly\" }")
			end
			local kind = item[1] or item.Kind
			if type(kind) ~= "string" or not Registry.KindSet[kind] then
				local guess = if type(kind) == "string" then Schema.closest(kind, Registry.KindSet) else nil
				fail(where, `unknown kind "{tostring(kind)}"{if guess then `, did you mean "{guess}"?` else ""}`)
			end
			local handle = call(where, container, kind, optionsOf(item))
			local key = item.Id or item.Flag
			if key ~= nil then
				elements[key] = handle
			end
		end
	end

	local function addPages(parent, list, path)
		for index, pageSpec in list or {} do
			local where = `{path}.Pages[{index}]`
			local page = call(where, parent, "Page", optionsOf(pageSpec))
			Build.fill(page, pageSpec, where, addElements, addPages)
		end
	end

	for index, tabSpec in spec.Tabs or {} do
		local where = `Tabs[{index}]`
		if type(tabSpec) ~= "table" then
			fail(where, "each tab is a table with a Title")
		end
		local tab = call(where, window, "Tab", optionsOf(tabSpec))
		Build.fill(tab, tabSpec, where, addElements, addPages)
	end

	if spec.SettingsTab then
		window:SettingsTab(if type(spec.SettingsTab) == "table" then spec.SettingsTab else nil)
	end
	if spec.Autoload ~= false then
		window:LoadAutoload()
	end
	return window, elements
end

-- Sections, loose elements and pages of one tab or page.
function Build.fill(target, spec, path, addElements, addPages)
	for index, sectionSpec in spec.Sections or {} do
		local where = `{path}.Sections[{index}]`
		local section = call(where, target, "Section", optionsOf(sectionSpec))
		addElements(section, sectionSpec.Elements, where)
		addPages(section, sectionSpec.Pages, where)
	end
	addElements(target, spec.Elements, path)
	addPages(target, spec.Pages, path)
end

return Build
