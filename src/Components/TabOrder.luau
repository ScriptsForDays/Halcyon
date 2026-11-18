-- With TabReorder on, the player arranges the navigation: drag a tab to a
-- new place within its group, or use its right-click (long-press) menu to
-- pin it to the top or move it a step. The order is saved per hub.

local Create = require("../Core/Create")
local Drag = require("../Core/Drag")
local Menu = require("./Menu")
local Strings = require("../Core/Strings")

local TabOrder = {}

function TabOrder.setup(window, saved)
	local state = { list = {}, pinned = {} }
	if type(saved) == "table" then
		for _, title in saved.order or {} do
			if type(title) == "string" then
				table.insert(state.list, title)
			end
		end
		for _, title in saved.pinned or {} do
			if type(title) == "string" then
				state.pinned[title] = true
			end
		end
	end
	window.tabOrder = state
end

function TabOrder.saved(window)
	local state = window.tabOrder
	if not state then
		return nil
	end
	local pinned = {}
	for title in state.pinned do
		table.insert(pinned, title)
	end
	table.sort(pinned)
	return { order = table.clone(state.list), pinned = pinned }
end

function TabOrder.isPinned(window, tab)
	return window.tabOrder ~= nil and window.tabOrder.pinned[tab.Title] == true
end

-- Where the player put this tab, or nil to keep the order it was made in.
function TabOrder.position(window, tab)
	return if window.tabOrder then table.find(window.tabOrder.list, tab.Title) else nil
end

-- Rewrites the saved order as the navigation shows it now, with `tab`
-- moved to just before `before` (or to the end of its group with nil).
local function placeBefore(window, tab, before)
	local shown = {}
	for _, other in window:navOrder() do
		if other ~= tab then
			table.insert(shown, other)
		end
	end
	local index = if before then table.find(shown, before) else nil
	if not index then
		-- After the last tab of the same group.
		index = #shown + 1
		for position = #shown, 1, -1 do
			if window:navGroup(shown[position]) == window:navGroup(tab) then
				index = position + 1
				break
			end
		end
	end
	table.insert(shown, index, tab)
	local titles = {}
	for _, other in shown do
		table.insert(titles, other.Title)
	end
	window.tabOrder.list = titles
	window:buildNav()
	window:savePreferences()
end

-- The tabs sharing `tab`'s place in the navigation (its group, or the pinned ones).
local function neighbours(window, tab)
	local list = {}
	for _, other in window:navOrder() do
		if not other.Hidden and window:navGroup(other) == window:navGroup(tab) then
			table.insert(list, other)
		end
	end
	return list
end

function TabOrder.move(window, tab, step)
	local list = neighbours(window, tab)
	local index = table.find(list, tab)
	local target = list[index + step]
	if not target then
		return
	end
	if step < 0 then
		placeBefore(window, tab, target)
	else
		placeBefore(window, tab, list[index + step + 1])
	end
end

function TabOrder.pin(window, tab, pinned)
	window.tabOrder.pinned[tab.Title] = if pinned then true else nil
	window:buildNav()
	window:savePreferences()
end

-- Hooks one navigation button. `vertical` is true for the sidebar and rail.
function TabOrder.attach(window, tab, scope, vertical)
	local button = tab.button
	if not button or tab.isFavourites then
		return
	end
	Menu.attach(scope, window.library, button, function()
		local pinned = TabOrder.isPinned(window, tab)
		return {
			{
				Title = if pinned then Strings.get("Unpin") else Strings.get("Pin to top"),
				Icon = "pin",
				Callback = function()
					TabOrder.pin(window, tab, not pinned)
				end,
			},
			{ Divider = true },
			{
				Title = Strings.get("Move up"),
				Icon = if vertical then "arrow-up" else "arrow-left",
				Callback = function()
					TabOrder.move(window, tab, -1)
				end,
			},
			{
				Title = Strings.get("Move down"),
				Icon = if vertical then "arrow-down" else "arrow-right",
				Callback = function()
					TabOrder.move(window, tab, 1)
				end,
			},
		}
	end)

	-- Dragging shows a line where the tab will land and moves it on release.
	local marker
	local target
	Drag.track(scope, button, nil, function(position, _, moved)
		if not moved then
			return
		end
		local list = neighbours(window, tab)
		target = nil
		local edge
		for _, other in list do
			local frame = other.button
			if frame and other ~= tab then
				local middle = frame.AbsolutePosition + frame.AbsoluteSize / 2
				local before = if vertical then position.Y < middle.Y else position.X < middle.X
				if before then
					target = other
					edge = frame
					break
				end
			end
		end
		-- The line sits on the navigation's own frame: inside the tab list a
		-- list layout would move it into line with the tabs.
		local host = window.navHost
		if not marker then
			marker = Create.new("Frame", {
				Name = "DropLine",
				ZIndex = 20,
				Theme = { BackgroundColor3 = "accent" },
				Parent = host,
			})
			Create.corner(-1, marker)
		end
		local anchor = edge or list[#list].button
		local parentOrigin = host.AbsolutePosition
		local place = anchor.AbsolutePosition - parentOrigin
		local scale = window.scale
		if vertical then
			marker.Size = UDim2.fromOffset(anchor.AbsoluteSize.X / scale, 2)
			marker.Position = UDim2.fromOffset(place.X / scale, (place.Y + (if edge then -2 else anchor.AbsoluteSize.Y + 1)) / scale)
		else
			marker.Size = UDim2.fromOffset(2, anchor.AbsoluteSize.Y / scale)
			marker.Position = UDim2.fromOffset((place.X + (if edge then -2 else anchor.AbsoluteSize.X + 1)) / scale, place.Y / scale)
		end
	end, function(moved)
		if marker then
			marker:Destroy()
			marker = nil
		end
		if moved then
			placeBefore(window, tab, target)
		end
	end)
end

return TabOrder
