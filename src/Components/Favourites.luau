-- Favourites: the player stars rows from their right-click (or long-press)
-- menu, and a Favourites tab at the top of the navigation shows a live copy
-- of each. A copy and its original stay in step both ways: changing either
-- changes the other, and only the original holds the Flag, so configs see
-- one value. Starred rows are remembered per hub in settings.json.

local Create = require("../Core/Create")
local Strings = require("../Core/Strings")
local Menu = require("./Menu")

local Favourites = {}

-- Controls whose value can be mirrored. Read-only displays have nothing to
-- change, and a Keybind's value is the key, not what its Callback hears.
local MIRRORED = {
	Toggle = true,
	Slider = true,
	Dropdown = true,
	Input = true,
	ColorPicker = true,
	Segmented = true,
	Radio = true,
	Checklist = true,
	Chips = true,
	Stepper = true,
	Button = true,
	Knob = true,
	Rating = true,
	Tiles = true,
	DatePicker = true,
	Tags = true,
	ItemGrid = true,
}

-- Options a copy must not repeat: its own flag, key chips and colour
-- add-ons (they would bind twice), one-time pointers and visibility rules.
local DROPPED = {
	Flag = true,
	Keybind = true,
	Color = true,
	Spotlight = true,
	Menu = true,
	Callback = true,
	Default = true,
	Value = true,
	Visible = true,
	ShowWhen = true,
	EnableWhen = true,
	Exclusive = true,
	Favourite = true,
}

-- Shows the copies in order, or the empty note when there are none.
local refresh

function Favourites.setup(window, saved)
	-- With no saved list yet, rows made with Favourite = true start starred.
	window.favourites = { order = {}, starred = {}, copies = {}, originals = {}, fresh = type(saved) ~= "table" }
	if type(saved) == "table" then
		for _, id in saved do
			if type(id) == "string" and not window.favourites.starred[id] then
				window.favourites.starred[id] = true
				table.insert(window.favourites.order, id)
			end
		end
	end
	window.makingFavourites = true
	local tab = window:Tab({ Title = Strings.get("Favourites"), Icon = "star" })
	window.makingFavourites = nil
	window.favourites.tab = tab
	tab.isFavourites = true
	refresh(window)
end

-- Rows are told apart by Flag when they have one, otherwise by where they
-- are and what they're called.
function Favourites.idOf(handle)
	if handle.Flag then
		return "flag:" .. handle.Flag
	end
	local tab = handle.Tab
	return `row:{if tab then tab.Title else ""}/{handle.Title}`
end

function refresh(window)
	local state = window.favourites
	local tab = state.tab
	-- The tab is always there, so players can find the feature; while it
	-- is empty it says how to fill it.
	local any = next(state.copies) ~= nil
	if any and state.empty then
		state.empty.Destroy()
		state.empty = nil
	elseif not any and not state.empty then
		state.empty = tab:EmptyState({
			Icon = "star",
			Title = Strings.get("No favourites yet"),
			Text = Strings.get("Right-click a row, or press and hold it, then choose Add to favourites."),
		})
	end
	for position, id in state.order do
		local copy = state.copies[id]
		if copy and copy.Frame then
			copy.Frame.LayoutOrder = position
		end
	end
end

local function save(window)
	window:savePreferences()
end

function Favourites.isStarred(window, handle)
	return window.favourites ~= nil and handle.favouriteId ~= nil and window.favourites.starred[handle.favouriteId] == true
end

local function makeCopy(window, original)
	local state = window.favourites
	local id = original.favouriteId
	if state.copies[id] or original.scope.cleaned then
		return
	end
	local options = {}
	for key, value in original.Options do
		if not DROPPED[key] then
			options[key] = value
		end
	end
	local where = original.Tab
	options.Description = if where then where.Title else original.Options.Description
	if original.Get then
		options.Default = original:Get()
		if original.Kind == "Progress" then
			options.Value = options.Default
		end
	end
	local syncing = false
	options.Callback = function(...)
		if syncing then
			return
		end
		syncing = true
		if original.Kind == "Button" then
			original:Press()
		elseif original.Set then
			original:Set(...)
		end
		syncing = false
	end
	local holder = state.tab
	local copy = holder[original.Kind](holder, options)
	copy.isCopy = true
	Menu.attach(copy.scope, window.library, copy.Frame, function()
		return { Favourites.menuItem(window, original) }
	end)
	state.copies[id] = copy
	-- The original changing (from code, a config, its own row) updates the
	-- copy without calling back into it.
	if original.Get and copy.SetSilent then
		copy.scope:add(original.Changed:Connect(function()
			if not syncing then
				syncing = true
				copy:SetSilent(original:Get())
				syncing = false
			end
		end))
	end
	copy.scope:add(function()
		if state.copies[id] == copy then
			state.copies[id] = nil
		end
	end)
	original.scope:add(function()
		copy:Destroy()
	end)
	refresh(window)
end

function Favourites.star(window, original, starred)
	local state = window.favourites
	local id = original.favouriteId
	if not state or not id then
		return
	end
	if starred and not state.starred[id] then
		state.starred[id] = true
		table.insert(state.order, id)
		makeCopy(window, original)
	elseif not starred and state.starred[id] then
		state.starred[id] = nil
		table.remove(state.order, table.find(state.order, id))
		local copy = state.copies[id]
		if copy then
			copy:Destroy()
		end
		refresh(window)
	end
	if original.favouriteMark then
		original.favouriteMark.Visible = state.starred[id] == true
	end
	save(window)
end

-- The menu entry that stars or unstars a row.
function Favourites.menuItem(window, original)
	local starred = Favourites.isStarred(window, original)
	return {
		Title = if starred then Strings.get("Remove from favourites") else Strings.get("Add to favourites"),
		Icon = "star",
		Callback = function()
			Favourites.star(window, original, not starred)
		end,
	}
end

-- Called for every row as it is made. Returns true when the row takes part.
function Favourites.register(window, handle, container)
	local state = window.favourites
	if not state or not MIRRORED[handle.Kind] or not handle.Frame or not handle.row then
		return false
	end
	local tab = container.tab or (container.section and container.section.tab)
	if tab and tab.isFavourites then
		return false
	end
	handle.favouriteId = Favourites.idOf(handle)
	state.originals[handle.favouriteId] = handle
	if state.fresh and handle.Options.Favourite == true and not state.starred[handle.favouriteId] then
		state.starred[handle.favouriteId] = true
		table.insert(state.order, handle.favouriteId)
	end
	-- A small star by the control marks a starred row where it lives.
	local mark = Create.icon("star", 12, "warning", handle.row.slot)
	mark.Name = "Favourite"
	mark.LayoutOrder = -10
	mark.Visible = state.starred[handle.favouriteId] == true
	handle.favouriteMark = mark
	if state.starred[handle.favouriteId] then
		-- Made a frame later, once the row has its Default and Callback in place.
		task.defer(makeCopy, window, handle)
	end
	return true
end

function Favourites.saved(window)
	return if window.favourites then table.clone(window.favourites.order) else nil
end

return Favourites
