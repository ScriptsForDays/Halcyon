-- Gives every Tab and Section one method per element, and does once what
-- each element needs: claim its Flag, make it searchable, apply its tier
-- lock, and undo all three when it is destroyed.

local Choices = require("./Choices")
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
	Radio = { new = Choices.radio },
	Checklist = { new = Choices.checklist },
	Chips = { new = Choices.chips },
	Tiles = require("./Tiles"),
	Rating = require("./Rating"),
	Accordion = require("./Accordion"),
	Status = require("./Status"),
	Countdown = require("./Countdown"),
	Buttons = require("./Buttons"),
	Space = require("./Space"),
	Table = require("./Table"),
	DatePicker = require("./DatePicker"),
}
local UNTITLED = { Divider = true, Code = true, Image = true, Buttons = true, Space = true, Table = true }

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
	handle.ownerWindow = window
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
	-- A row made while its section's switch is off, or the window is
	-- disabled, starts greyed like its neighbours.
	if handle.SetBlocked and ((container.section and container.section.switchedOff) or window.disabledAll) then
		handle:SetBlocked(true)
	end
	function handle.ShowWhen(target, source, expected)
		Registry.follow(target, source, expected)
	end
	if window.query ~= "" then
		window:applySearch()
	end
	return handle
end

-- Makes `target` (a row or section) visible only while `source` matches.
-- `source` is an element or its Flag; `expected` is a value (a multi
-- dropdown matches when it includes it) or a function of the value.
function Registry.follow(target, source, expected)
	local window = target.window or target.ownerWindow
	if type(source) == "string" then
		source = window and window.Flags[source]
	end
	if type(source) ~= "table" or not source.Changed or not source.Get then
		error("ShowWhen needs an element, or the Flag of one made before it", 3)
	end
	if expected == nil then
		expected = true
	end
	local function check()
		local value = source:Get()
		local shown
		if type(expected) == "function" then
			local ok, result = pcall(expected, value)
			shown = ok and result == true
		elseif type(value) == "table" then
			shown = table.find(value, expected) ~= nil
		else
			shown = value == expected
		end
		target:SetVisible(shown)
	end
	target.scope:connect(source.Changed, check)
	check()
end

function Registry.install(container)
	for kind in MODULES do
		container[kind] = function(self, options)
			return create(self, kind, options)
		end
	end
end

return Registry
