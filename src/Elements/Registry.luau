-- Gives every Tab and Section one method per element, and does once what
-- each element needs: claim its Flag, make it searchable, apply its tier
-- lock, and undo all three when it is destroyed.

local Env = require("../Core/Env")

local MODULES = {
	Button = require("./Button"),
	Toggle = require("./Toggle"),
	Slider = require("./Slider"),
	Dropdown = require("./Dropdown"),
	Input = require("./Input"),
	Keybind = require("./Keybind"),
	ColorPicker = require("./ColorPicker"),
	Segmented = require("./Segmented"),
	Stepper = require("./Stepper"),
	Progress = require("./Progress"),
	Paragraph = require("./Paragraph"),
	Label = require("./Label"),
	Divider = require("./Divider"),
	Code = require("./Code"),
	Image = require("./Image"),
}
local UNTITLED = { Divider = true, Code = true, Image = true }

local Registry = { Kinds = {} }
for kind in MODULES do
	table.insert(Registry.Kinds, kind)
end
table.sort(Registry.Kinds)

local function create(container, kind, options)
	if type(options) == "string" then
		options = { Title = options }
	end
	options = options or {}
	if type(options) ~= "table" then
		error(`{kind} expects a table of options`, 3)
	elseif not UNTITLED[kind] and type(options.Title) ~= "string" then
		error(`{kind} needs a Title`, 3)
	end

	-- Refuse a duplicate Flag before anything is built, so a rejected element leaves no half-made row.
	local window = container.window
	local problem = window:checkFlag(options.Flag)
	if problem then
		error(problem, 3)
	end

	local handle = MODULES[kind].new(container, options)
	handle.Kind = kind
	window:claimFlag(options.Flag, handle)

	local entry = { handle = handle, section = container.section }
	table.insert(container.entries, entry)
	handle.scope:add(function()
		local index = table.find(container.entries, entry)
		if index then
			table.remove(container.entries, index)
		end
	end)

	-- The row's own setting wins over its section's or tab's, so one paid row
	-- can sit inside a section locked to another tier.
	local requirement = options.Tier or (options.PaidOnly and true) or container.tier
	if requirement then
		handle.LockText = options.LockText or container.lockText
		handle.LockHint = options.LockHint or container.lockHint
		-- A row locked only because its section is locked stays quiet under
		-- the section's one overlay.
		handle.QuietLock = container.lockOverlay ~= nil and options.Tier == nil and not options.PaidOnly
		window:gate(handle, requirement)
	end
	-- Requires lists executor functions the row needs; without them it is
	-- locked with their names instead of failing when used.
	if type(options.Requires) == "table" then
		local missing = Env.missing(options.Requires)
		if #missing > 0 then
			handle.MissingText = "Needs " .. table.concat(missing, ", ")
			handle:Lock(handle.MissingText, "wrench")
		end
	end
	if window.query ~= "" then
		window:applySearch()
	end
	return handle
end

function Registry.install(container)
	for kind in MODULES do
		container[kind] = function(self, options)
			return create(self, kind, options)
		end
	end
end

return Registry
