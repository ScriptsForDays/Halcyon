-- A search box over every tab and row in the window. Typing lists matches;
-- the arrow keys move between them, Enter or a click jumps there, Escape
-- closes. Opened with Ctrl+K (or the hub's PaletteKey) when the window has
-- CommandPalette = true, or with Window:OpenPalette().

local UserInputService = game:GetService("UserInputService")

local Create = require("../Core/Create")
local Motion = require("../Core/Motion")
local Mount = require("../Core/Mount")
local Strings = require("../Core/Strings")
local SearchFocus = require("./SearchFocus")

local WIDTH, RESULTS = 460, 8

local CommandPalette = {}

-- Every place the palette can jump to: tabs, then rows, with where each lives.
local function catalogue(window)
	local items = {}
	local places = table.clone(window.tabs)
	for _, page in window.subPages do
		table.insert(places, page)
	end
	for _, tab in places do
		if tab.Hidden or (tab.rootTab and tab.rootTab.Hidden) then
			continue
		end
		local where = if tab.isPage then tab.parentTab.Title else "Tab"
		table.insert(items, { kind = "tab", tab = tab, title = tab.Title, path = where, icon = tab.Icon or (tab.rootTab and tab.rootTab.Icon) or "layout-grid" })
		for _, entry in tab.entries do
			local handle = entry.handle
			if not handle.Hidden and not (entry.section and entry.section.Hidden) and handle.Title and handle.Title ~= "" then
				local section = entry.section and entry.section.Title
				table.insert(items, {
					kind = "row",
					tab = tab,
					handle = handle,
					title = handle.Title,
					path = if section then `{tab.Title}  \u{203A}  {section}` else tab.Title,
					icon = tab.Icon or "circle",
					words = handle.SearchText or string.lower(handle.Title),
				})
			end
		end
	end
	return items
end

-- Titles that start with the query come first, then any that contain it.
local function search(items, query)
	query = string.lower(query)
	local starts, contains = {}, {}
	for _, item in items do
		local title = string.lower(item.title)
		if query == "" then
			if item.kind == "tab" then
				table.insert(starts, item)
			end
		elseif string.sub(title, 1, #query) == query then
			table.insert(starts, item)
		elseif string.find(item.words or title, query, 1, true) then
			table.insert(contains, item)
		end
	end
	for _, item in contains do
		table.insert(starts, item)
	end
	return starts
end

-- Brings the row into view in its page and marks it for a moment.
local function reveal(window, item)
	window:Show()
	if window.minimized then
		window:Minimize(false)
	end
	if window.query ~= "" then
		window:Search("")
	end
	window:SelectTab(item.tab)
	local handle = item.handle
	if not handle then
		return
	end
	SearchFocus.reveal(window, item.tab, handle)
end

function CommandPalette.open(window)
	local library = window.library
	if library.palette then
		library.palette.close()
	end
	local overlay = Mount.overlay(library)
	local scope = window.scope:child()
	local palette = {}
	library.palette = palette

	local scrim = Create.new("TextButton", {
		Name = "Palette",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Parent = overlay.dialogs,
	})
	scope:add(scrim)
	Motion.tween(scrim, "fast", { BackgroundTransparency = 0.55 })
	local card = Create.new("Frame", {
		Name = "Card",
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.16, 0),
		Active = true,
		Theme = { BackgroundColor3 = "surface" },
		Parent = scrim,
	})
	Create.new("UIScale", { Scale = library.scale, Parent = card })
	Create.new("UISizeConstraint", { MaxSize = Vector2.new(math.max(overlay.gui.AbsoluteSize.X / library.scale - 24, 240), math.huge), Parent = card })
	Create.corner(12, card)
	Create.stroke("stroke", card)
	Create.list(card, "Vertical", 0)

	local bar = Create.new("Frame", { Name = "Bar", Size = UDim2.new(1, 0, 0, 48), Parent = card })
	Create.padding(bar, 16, 0)
	Create.list(bar, "Horizontal", 10)
	Create.icon("search", 16, "textMuted", bar)
	local box = Create.new("TextBox", {
		Name = "Query",
		Size = UDim2.fromScale(0, 1),
		PlaceholderText = Strings.get("Jump to a tab or setting"),
		TextSize = 14,
		LayoutOrder = 1,
		Theme = { TextColor3 = "text" },
		Parent = bar,
	}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	local hint = Create.new("TextLabel", {
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = Strings.get("Esc"),
		TextSize = 12,
		Weight = "bold",
		LayoutOrder = 2,
		Theme = { BackgroundColor3 = "raised", TextColor3 = "textMuted" },
		Parent = bar,
	})
	Create.corner(4, hint)
	Create.padding(hint, 6, 0)
	local list = Create.new("Frame", { Name = "Results", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = card })
	Create.padding(list, 6)
	Create.list(list, "Vertical", 2)

	local items = catalogue(window)
	local shown, buttons, chosen = {}, {}, 1

	local function paint()
		for index, button in buttons do
			local on = index == chosen
			button.BackgroundTransparency = if on then 0 else 1
		end
	end

	function palette.close()
		if library.palette ~= palette then
			return
		end
		library.palette = nil
		window.scope:release(scope)
	end

	local function jump(item)
		palette.close()
		if item then
			reveal(window, item)
		end
	end

	local function draw()
		for _, button in buttons do
			button:Destroy()
		end
		table.clear(buttons)
		shown = search(items, box.Text)
		chosen = 1
		for index = 1, math.min(#shown, RESULTS) do
			local item = shown[index]
			local button = Create.new("TextButton", {
				Name = "Result",
				Size = UDim2.new(1, 0, 0, if library.touch then 48 else 42),
				LayoutOrder = index,
				BackgroundTransparency = 1,
				Theme = { BackgroundColor3 = "raised" },
				Parent = list,
			})
			Create.corner(8, button)
			Create.padding(button, 10, 0)
			Create.list(button, "Horizontal", 10)
			Create.icon(if item.kind == "tab" then item.icon else "chevron-right", 16, if item.kind == "tab" then "accent" else "textMuted", button)
			local text = Create.new("Frame", { Size = UDim2.fromScale(0, 1), LayoutOrder = 1, Parent = button }, {
				Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
			})
			Create.list(text, "Vertical", 0, { VerticalAlignment = Enum.VerticalAlignment.Center })
			Create.new("TextLabel", {
				Size = UDim2.new(1, 0, 0, 17),
				Text = item.title,
				TextSize = 14,
				Weight = "medium",
				TextTruncate = Enum.TextTruncate.AtEnd,
				Theme = { TextColor3 = "text" },
				Parent = text,
			})
			Create.new("TextLabel", {
				Size = UDim2.new(1, 0, 0, 14),
				Text = item.path,
				TextSize = 12,
				TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = 1,
				Theme = { TextColor3 = "textMuted" },
				Parent = text,
			})
			scope:connect(button.MouseEnter, function()
				chosen = index
				paint()
			end)
			scope:connect(button.Activated, function()
				jump(item)
			end)
			buttons[index] = button
		end
		if #buttons == 0 then
			local empty = Create.new("TextLabel", {
				Name = "Result",
				Size = UDim2.new(1, 0, 0, 40),
				Text = Strings.get('Nothing matches "{query}".', { query = box.Text }),
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Center,
				Theme = { TextColor3 = "textMuted" },
				Parent = list,
			})
			table.insert(buttons, empty)
		end
		paint()
	end

	scope:connect(box:GetPropertyChangedSignal("Text"), draw)
	scope:connect(scrim.Activated, palette.close)
	scope:connect(UserInputService.InputBegan, function(input)
		local key = input.KeyCode
		if key == Enum.KeyCode.Escape then
			palette.close()
		elseif key == Enum.KeyCode.Down then
			chosen = math.min(chosen + 1, math.min(#shown, RESULTS))
			paint()
		elseif key == Enum.KeyCode.Up then
			chosen = math.max(chosen - 1, 1)
			paint()
		end
	end)
	scope:connect(box.FocusLost, function(entered)
		if entered then
			jump(shown[chosen])
		end
	end)
	draw()
	task.defer(function()
		if library.palette == palette then
			box:CaptureFocus()
		end
	end)
	palette.box, palette.items, palette.jump = box, items, jump
	palette.results = function()
		return shown
	end
	return palette
end

-- Ctrl+K (or Ctrl and the hub's PaletteKey) opens the palette.
function CommandPalette.bind(window)
	local key = window.options.PaletteKey or Enum.KeyCode.K
	window.scope:connect(UserInputService.InputBegan, function(input, processed)
		if processed or input.KeyCode ~= key or window.library.listeningForKey or window.paletteOff then
			return
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
			CommandPalette.open(window)
		end
	end)
end

return CommandPalette
