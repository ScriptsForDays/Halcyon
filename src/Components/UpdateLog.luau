-- The hub's update log: a tab of releases, newest first, each with its
-- changes grouped by kind. Turned on with UpdateLog = true (or a table of
-- settings); releases come from UpdateLog.Updates and Window:AddUpdate.

local Create = require("../Core/Create")
local Panels = require("./Panels")
local Row = require("../Elements/Row")
local Styles = require("../Core/Styles")

local KINDS = { "New", "Improved", "Fixed", "Removed", "Security" }
local ROLES = { New = "accent", Improved = "info", Fixed = "success", Removed = "danger", Security = "warning" }
local ICONS = { New = "plus", Improved = "zap", Fixed = "wrench", Removed = "trash-2", Security = "shield-check" }

-- How releases are drawn (kind "UpdateLog").
--   section  the Section look each release uses
--   compact  entries as single lines without kind headings
Styles.register("UpdateLog", "Timeline", { section = "Accent" })
Styles.register("UpdateLog", "Cards", { section = "Card" })
Styles.register("UpdateLog", "Compact", { section = "Outlined", compact = true })

local UpdateLog = {}

-- `true`, a table of settings, or anything else for none.
function UpdateLog.settings(value)
	if value == true then
		return {}
	elseif type(value) == "table" then
		return value
	end
	return nil
end

-- Version strings compare number by number: 2.10 is newer than 2.9.
local function newer(a, b)
	local left, right = {}, {}
	for number in string.gmatch(tostring(a.Version or ""), "%d+") do
		table.insert(left, tonumber(number))
	end
	for number in string.gmatch(tostring(b.Version or ""), "%d+") do
		table.insert(right, tonumber(number))
	end
	for index = 1, math.max(#left, #right) do
		local x, y = left[index] or 0, right[index] or 0
		if x ~= y then
			return x > y
		end
	end
	return (a.order or 0) > (b.order or 0)
end

local function entriesOf(update)
	local list = {}
	for _, entry in update.Entries or {} do
		if type(entry) == "string" then
			table.insert(list, { Kind = "New", Text = entry })
		elseif type(entry) == "table" and entry.Text then
			table.insert(list, { Kind = if ROLES[entry.Kind] then entry.Kind else "New", Text = tostring(entry.Text) })
		end
	end
	return list
end

-- One kind's changes inside a release: a tag with the count, then a line
-- per change. In the compact look each change is a single tagged line.
local function group(section, kind, items, compact)
	local row = Row.new(section, { Title = "" }, { bare = true, compact = true })
	local handle = row.handle
	local body = Create.new("Frame", { Name = "Group", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = row.content })
	Create.list(body, "Vertical", 6)
	local role = ROLES[kind]
	if not compact then
		local head = Create.new("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, 20), Parent = body })
		Create.list(head, "Horizontal", 6)
		Create.icon(ICONS[kind], 14, role, head)
		Create.new("TextLabel", {
			Name = "Kind",
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = string.upper(kind),
			TextSize = 12,
			Weight = "bold",
			LayoutOrder = 1,
			Theme = { TextColor3 = role },
			Parent = head,
		})
		local count = Create.new("TextLabel", {
			Name = "Count",
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = tostring(#items),
			TextSize = 12,
			Weight = "bold",
			LayoutOrder = 2,
			BackgroundTransparency = 0.85,
			Theme = { BackgroundColor3 = role, TextColor3 = role },
			Parent = head,
		})
		Create.corner(-1, count)
		Create.padding(count, 6, 0)
	end
	local words = {}
	for index, text in items do
		local line = Create.new("Frame", { Name = "Change", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = index + 1, Parent = body })
		Create.list(line, "Horizontal", 8, { VerticalAlignment = Enum.VerticalAlignment.Top })
		if compact then
			local tag = Create.new("TextLabel", {
				Name = "Tag",
				Size = UDim2.fromOffset(78, 18),
				Text = string.upper(kind),
				TextSize = 12,
				Weight = "bold",
				TextXAlignment = Enum.TextXAlignment.Center,
				BackgroundTransparency = 0.85,
				Theme = { BackgroundColor3 = role, TextColor3 = role },
				Parent = line,
			})
			Create.corner(4, tag)
		else
			local dot = Create.new("Frame", { Name = "Dot", Size = UDim2.fromOffset(5, 5), Position = UDim2.fromOffset(0, 7), Theme = { BackgroundColor3 = "textMuted" } })
			local holder = Create.new("Frame", { Name = "Bullet", Size = UDim2.fromOffset(12, 18), Parent = line })
			dot.Parent = holder
			dot.Position = UDim2.fromOffset(4, 7)
			Create.corner(-1, dot)
		end
		Create.new("TextLabel", {
			Name = "Text",
			Size = UDim2.fromScale(0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			RichText = true,
			TextSize = 13,
			LayoutOrder = 1,
			Text = text,
			Theme = { TextColor3 = "text" },
			Parent = line,
		}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
		table.insert(words, text)
	end
	handle.SearchExtra = kind .. " " .. table.concat(words, " ")
	handle.SearchText = string.lower(handle.SearchExtra)
	handle.Kind = "UpdateGroup"
	handle.UpdateKind = kind
	local entry = { handle = handle, section = section }
	table.insert(section.entries, entry)
	handle.scope:add(function()
		local index = table.find(section.entries, entry)
		if index then
			table.remove(section.entries, index)
		end
	end)
	return handle
end

function UpdateLog.build(window, settings)
	local look = Styles.pick("UpdateLog", settings.Style, window)
	local tab = window:Tab({
		Title = settings.Title or "Updates",
		Icon = settings.Icon or "clock",
		Group = settings.Group,
		Description = settings.Description,
	})
	local log = { tab = tab, updates = {}, sections = {}, filter = "All", query = "", order = 0 }
	window.updateLog = log

	-- Search and kind filters sit above the releases when there is enough to
	-- sift through; a short log does not need them.
	local tools = tab:Section({ Title = nil })
	local chips
	local function apply()
		for _, section in log.sections do
			local shown = 0
			for _, entry in section.entries do
				local handle = entry.handle
				-- A tab's sections share one entry list; only this release's rows count.
				if handle.UpdateKind and entry.section == section then
					local visible = (log.filter == "All" or handle.UpdateKind == log.filter)
						and (log.query == "" or string.find(handle.SearchText, log.query, 1, true) ~= nil or string.find(section.searchTitle or "", log.query, 1, true) ~= nil)
					handle:SetVisible(visible)
					if visible then
						shown += 1
					end
				end
			end
			section:SetVisible(shown > 0)
			if shown > 0 and (log.query ~= "" or log.filter ~= "All") then
				section:SetCollapsed(false)
			end
		end
	end
	if settings.Search ~= false then
		tools:Input({
			Title = "Search updates",
			Placeholder = "Search updates",
			LeadingIcon = "search",
			Clearable = true,
			Live = true,
			Callback = function(text)
				log.query = string.lower(text or "")
				apply()
			end,
		})
	end
	if settings.Filters ~= false then
		local values = { "All" }
		for _, kind in KINDS do
			table.insert(values, kind)
		end
		chips = tools:Chips({
			Title = "Show",
			Values = values,
			Default = "All",
			Callback = function(kind)
				log.filter = kind or "All"
				apply()
			end,
		})
	end
	log.tools, log.chips = tools, chips

	function log.redraw()
		for _, section in log.sections do
			section:Destroy()
		end
		table.clear(log.sections)
		table.sort(log.updates, function(a, b)
			if (a.Pinned == true) ~= (b.Pinned == true) then
				return a.Pinned == true
			end
			return newer(a, b)
		end)
		for index, update in log.updates do
			local latest = index == 1
			local title = tostring(update.Version or "")
			if update.Title then
				title = if title ~= "" then `{title}  \u{00B7}  {update.Title}` else tostring(update.Title)
			end
			local subtitle = {}
			if update.Date then
				table.insert(subtitle, tostring(update.Date))
			end
			if update.Summary then
				table.insert(subtitle, tostring(update.Summary))
			end
			local section = tab:Section({
				Title = title,
				Icon = if latest then "tag" else "clock",
				IconColor = if latest then "accent" else nil,
				Style = look.section,
				Description = if #subtitle > 0 then table.concat(subtitle, "  \u{2014}  ") else nil,
				Badge = if latest then "Latest" elseif update.Pinned then "Pinned" else nil,
				Collapsed = not latest and settings.ExpandAll ~= true,
			})
			if update.Image then
				section:Image({ Image = update.Image, Height = 120, Crop = true })
			end
			local byKind = {}
			for _, entry in entriesOf(update) do
				byKind[entry.Kind] = byKind[entry.Kind] or {}
				table.insert(byKind[entry.Kind], entry.Text)
			end
			for _, kind in KINDS do
				if byKind[kind] then
					group(section, kind, byKind[kind], look.compact)
				end
			end
			table.insert(log.sections, section)
		end
		apply()
		log.markUnseen()
	end

	-- A badge on the tab while the newest release has not been looked at.
	function log.markUnseen()
		local newest = log.updates[1]
		local version = newest and tostring(newest.Version or "")
		if version and version ~= "" and window.updateSeen ~= version and window.selected ~= tab then
			tab:SetBadge("New")
		else
			tab:SetBadge(nil)
		end
	end
	tab.scope:add(window.TabChanged:Connect(function(selected)
		local newest = log.updates[1]
		if selected == tab and newest and newest.Version then
			window.updateSeen = tostring(newest.Version)
			window:savePreferences()
			tab:SetBadge(nil)
		end
	end))

	function log.add(update)
		if type(update) ~= "table" then
			error("AddUpdate expects a table: { Version, Title, Date, Entries }", 3)
		end
		log.order += 1
		local copy = table.clone(update)
		copy.order = log.order
		table.insert(log.updates, copy)
		log.redraw()
	end

	for _, update in settings.Updates or {} do
		log.order += 1
		local copy = table.clone(update)
		copy.order = log.order
		table.insert(log.updates, copy)
	end
	log.redraw()

	-- Popup = true also shows the newest release once, as a What's new card.
	if settings.Popup and log.updates[1] then
		local newest = log.updates[1]
		task.defer(function()
			if not window.scope.cleaned then
				local entries = {}
				for _, entry in entriesOf(newest) do
					table.insert(entries, entry)
				end
				pcall(Panels.changelog, window, { Version = newest.Version, Title = newest.Title and `What's new: {newest.Title}`, Entries = entries })
			end
		end)
	end
	return log
end

return UpdateLog
