-- Gives every Tab and Section one method per element, and does once what
-- each element needs: claim its Flag, make it searchable, apply its tier
-- lock, and undo all three when it is destroyed.

local Choices = require("./Choices")
local Env = require("../Core/Env")
local Menu = require("../Components/Menu")
local Spotlight = require("../Components/Spotlight")
local Gauge = require("./Gauge")
local Stat = require("./Stat")
local Strings = require("../Core/Strings")
local Tooltip = require("../Components/Tooltip")
local Schema = require("../Core/Schema")

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
	List = require("./List"),
	Tags = require("./Tags"),
	PlayerList = require("./PlayerList"),
	MenuButton = require("./MenuButton"),
	Stat = Stat,
	Stats = { new = Stat.group },
	Graph = require("./Graph"),
	Log = require("./Log"),
	Banner = require("./Banner"),
	Link = require("./Link"),
	Viewport = require("./Viewport"),
	Gauge = Gauge,
	Knob = { new = Gauge.knob },
	Chart = require("./Chart"),
	ItemGrid = require("./ItemGrid"),
	Waypoints = require("./Waypoints"),
}
local UNTITLED = { Divider = true, Code = true, Image = true, Buttons = true, Space = true, Table = true, Stats = true }

local Registry = { Kinds = {}, KindSet = {}, custom = {} }
for kind in MODULES do
	table.insert(Registry.Kinds, kind)
	Registry.KindSet[kind] = true
end
table.sort(Registry.Kinds)

-- ShowWhen and EnableWhen name what they follow: an element or its Flag on
-- its own (waiting for true), or with the value to wait for, as
-- { "Flag", value } or { Flag = "Flag", Value = value }.
local function condition(setting)
	if type(setting) == "table" and not setting.Get then
		local value = setting.Value
		if value == nil then
			value = setting[2]
		end
		return setting.Flag or setting[1], value
	end
	return setting, nil
end
Registry.condition = condition

-- Whether a row is greyed by something other than itself: the window's
-- SetEnabled(false), or its section's switch or Enabled = false.
function Registry.blocked(window, section)
	return window.disabledAll == true or (section ~= nil and (section.switchedOff == true or section.disabled == true))
end

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

	local spec = Schema.elements[kind] or Registry.custom[kind]
	if spec then
		Schema.check(`{kind} "{options.Title or ""}"`, options, spec.options, Schema.shared)
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
			handle.MissingText = Strings.get("Needs {names}", { names = table.concat(missing, ", ") })
			handle:Lock(handle.MissingText, "wrench")
		end
	end
	-- A row made while its section's switch is off, or the window is
	-- disabled, starts greyed like its neighbours.
	if handle.SetBlocked and Registry.blocked(window, container.section) then
		handle:SetBlocked(true)
	end
	-- A string or table is a hover tip; a slider's Tooltip = true/false is its value bubble.
	if (type(options.Tooltip) == "string" or type(options.Tooltip) == "table") and handle.row then
		Tooltip.attach(handle.row, options.Tooltip)
	end
	handle.Tab = container.tab or (container.section and container.section.tab)
	-- Spotlight = "text" or { Title, Text, Id } points at a new feature once.
	if options.Spotlight then
		Spotlight.attach(window, handle, options.Spotlight)
	end
	function handle.Spotlight(target, settings)
		return Spotlight.attach(window, target, settings)
	end
	function handle.ShowWhen(target, source, expected)
		Registry.follow(target, source, expected)
	end
	function handle.EnableWhen(target, source, expected)
		Registry.enableWhen(target, source, expected)
	end
	function handle.SetEnabled(target, enabled)
		if target.SetDisabled then
			target:SetDisabled(enabled == false)
		end
	end
	handle.Options = options
	if handle.Get and handle.Set then
		Registry.values(handle)
	end
	-- Visible, Enabled, ShowWhen and EnableWhen: the same switches as the
	-- methods, given when the row is made.
	Registry.switches(handle, options)
	-- Menu = { items } (or a function returning them) opens on right-click
	-- or a long press on the row.
	if (type(options.Menu) == "table" or type(options.Menu) == "function") and handle.Frame then
		Menu.attach(handle.scope, window.library, handle.Frame, options.Menu)
	end
	if window.query ~= "" then
		window:applySearch()
	end
	return handle
end

-- Runs `apply(matches)` now and whenever `source` changes. `source` is an
-- element or its Flag; `expected` is a value (a multi dropdown matches when
-- it includes it) or a function of the value. With `late`, a Flag that isn't
-- made yet is looked up again once the hub's current build step finishes, so
-- a row given ShowWhen when it is made may follow a control made below it.
local function watch(target, source, expected, apply, name, late)
	local window = target.window or target.ownerWindow
	if expected == nil then
		expected = true
	end
	local function attach(element)
		local function check()
			local value = element:Get()
			local matches
			if type(expected) == "function" then
				local ok, result = pcall(expected, value)
				matches = ok and result == true
			elseif type(value) == "table" then
				matches = table.find(value, expected) ~= nil
			else
				matches = value == expected
			end
			apply(matches)
		end
		target.scope:connect(element.Changed, check)
		check()
	end
	if type(source) == "string" then
		local flag = source
		source = window and window.Flags[flag]
		if source == nil and window and late then
			task.defer(function()
				if target.scope.cleaned then
					return
				end
				local late = window.Flags[flag]
				if type(late) == "table" and late.Changed and late.Get then
					attach(late)
				else
					warn(`[Halcyon] {name} names the Flag "{flag}", but no element has it.`)
				end
			end)
			return
		end
	end
	if type(source) ~= "table" or not source.Changed or not source.Get then
		error(`{name} needs an element, or the Flag of one`, 4)
	end
	attach(source)
end

-- Makes `target` (a row, section or tab) visible only while `source` matches.
function Registry.follow(target, source, expected, late)
	watch(target, source, expected, function(shown)
		target:SetVisible(shown)
	end, "ShowWhen", late)
end

-- Greys `target` (a row or section) while `source` does not match.
function Registry.enableWhen(target, source, expected, late)
	watch(target, source, expected, function(enabled)
		target:SetEnabled(enabled)
	end, "EnableWhen", late)
end

-- Applies Visible, Enabled, ShowWhen and EnableWhen given when a row,
-- section or tab is made.
function Registry.switches(target, options)
	if options.Visible == false and target.SetVisible then
		target:SetVisible(false)
	end
	if (options.Enabled == false or options.Disabled == true) and target.SetEnabled then
		target:SetEnabled(false)
	end
	if options.ShowWhen ~= nil then
		local source, expected = condition(options.ShowWhen)
		Registry.follow(target, source, expected, true)
	end
	if options.EnableWhen ~= nil then
		local source, expected = condition(options.EnableWhen)
		Registry.enableWhen(target, source, expected, true)
	end
end

-- A copy that later changes to the live value can't reach.
local function copy(value)
	return if type(value) == "table" then table.clone(value) else value
end

-- SetSilent, Reset and GetDefault for an element that holds a value. The
-- default is the value it had when made, kept in its saved form so colours
-- and keys come back exactly.
function Registry.values(handle)
	local row = handle.row
	local function read()
		return copy(if handle.Encode then handle:Encode() else handle:Get())
	end
	local function write(saved)
		handle:Set(if handle.Decode then handle:Decode(copy(saved)) else copy(saved))
	end
	local default = read()

	-- Sets the value and fires Changed without running the Callback.
	function handle.SetSilent(target, value)
		if not row then
			target:Set(value)
			return
		end
		row.silent = true
		local ok, problem = pcall(target.Set, target, value)
		row.silent = false
		if not ok then
			error(problem, 2)
		end
	end
	function handle.GetDefault()
		return if handle.Decode then handle:Decode(copy(default)) else copy(default)
	end
	function handle.Reset()
		write(default)
	end
	handle.readSaved, handle.writeSaved = read, write
end

function Registry.install(container)
	for kind in MODULES do
		container[kind] = function(self, options)
			return create(self, kind, options)
		end
	end
end

return Registry
