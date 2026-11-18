local Create = require("../Core/Create")
local Motion = require("../Core/Motion")
local Popup = require("../Components/Popup")
local Row = require("./Row")
local Strings = require("../Core/Strings")
local Theme = require("../Core/Theme")

local MONTHS = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }

local DatePicker = {}

local function daysIn(year, month)
	return os.date("*t", os.time({ year = year, month = month + 1, day = 0, hour = 12 })).day
end

-- 1 for the first day of the week the grid starts on.
local function firstColumn(year, month, mondayFirst)
	local weekday = os.date("*t", os.time({ year = year, month = month, day = 1, hour = 12 })).wday
	return if mondayFirst then (weekday + 5) % 7 + 1 else weekday
end

local function copy(date)
	return { Year = date.Year, Month = date.Month, Day = date.Day, Hour = date.Hour, Minute = date.Minute }
end

-- A date, and optionally a time, picked from a calendar.
-- Options: Default ({ Year, Month, Day, Hour, Minute }; today when left
-- out), Time (adds hour and minute), WeekStart ("Monday" or "Sunday"),
-- Width. The value is a table of the same shape.
function DatePicker.new(container, options)
	local row = Row.new(container, options, { button = true })
	local handle, scope, library = row.handle, row.scope, row.library
	local now = os.date("*t")
	local default = options.Default or {}
	local value = {
		Year = tonumber(default.Year) or now.year,
		Month = math.clamp(tonumber(default.Month) or now.month, 1, 12),
		Day = tonumber(default.Day) or now.day,
		Hour = math.clamp(tonumber(default.Hour) or 12, 0, 23),
		Minute = math.clamp(tonumber(default.Minute) or 0, 0, 59),
	}
	value.Day = math.clamp(value.Day, 1, daysIn(value.Year, value.Month))
	local mondayFirst = options.WeekStart ~= "Sunday"
	local withTime = options.Time == true

	local chip = Create.new("Frame", { Name = "Value", Theme = { BackgroundColor3 = row.controlRole } })
	row.placeControl(chip, options.Width or (if withTime then 170 else 140), math.max(row.reach, 30))
	Create.corner(6, chip)
	Create.stroke("stroke", chip)
	Create.padding(chip, 10, 0)
	Create.list(chip, "Horizontal", 8)
	Create.icon("calendar", 14, "textMuted", chip)
	local label = Create.new("TextLabel", {
		Size = UDim2.fromScale(0, 1),
		TextSize = 13,
		LayoutOrder = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = "text" },
		Parent = chip,
	}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })

	row.onHover(function(active)
		local role = if active then "hover" else row.controlRole
		Theme.bind(chip, "BackgroundColor3", role, true)
		Motion.tween(chip, "fast", { BackgroundColor3 = Theme.color(role) })
	end, chip)

	local function draw()
		local text = string.format("%d %s %d", value.Day, string.sub(Strings.get(MONTHS[value.Month]), 1, 3), value.Year)
		if withTime then
			text ..= string.format("  %02d:%02d", value.Hour, value.Minute)
		end
		label.Text = text
	end

	function handle:Get()
		return copy(value)
	end

	function handle:Set(date)
		if type(date) ~= "table" then
			return
		end
		value.Year = tonumber(date.Year) or value.Year
		value.Month = math.clamp(tonumber(date.Month) or value.Month, 1, 12)
		value.Day = math.clamp(tonumber(date.Day) or value.Day, 1, daysIn(value.Year, value.Month))
		value.Hour = math.clamp(tonumber(date.Hour) or value.Hour, 0, 23)
		value.Minute = math.clamp(tonumber(date.Minute) or value.Minute, 0, 59)
		draw()
		row.fire(self:Get())
	end

	-- The value as seconds since 1970 in the player's time zone.
	function handle:GetTimestamp()
		return os.time({ year = value.Year, month = value.Month, day = value.Day, hour = value.Hour, min = value.Minute })
	end

	scope:connect(row.frame.Activated, function()
		local popup = Popup.toggle(library, chip, { Width = 252 })
		if not popup then
			return
		end
		local session = popup.scope
		local shown = { Year = value.Year, Month = value.Month }
		local cell = if library.touch then 34 else 30

		local header = Create.new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 28), Parent = popup.frame })
		local title = Create.new("TextLabel", {
			Size = UDim2.new(1, -64, 1, 0),
			Position = UDim2.fromOffset(32, 0),
			TextSize = 13,
			Weight = "bold",
			TextXAlignment = Enum.TextXAlignment.Center,
			Theme = { TextColor3 = "text" },
			Parent = header,
		})
		local function arrow(icon, side)
			local button = Create.new("ImageButton", {
				Name = icon,
				Size = UDim2.fromOffset(28, 28),
				AnchorPoint = Vector2.new(side, 0),
				Position = UDim2.fromScale(side, 0),
				BackgroundTransparency = 1,
				Theme = { BackgroundColor3 = "hover" },
				Parent = header,
			})
			Create.corner(6, button)
			local glyph = Create.icon(icon, 14, "text", button)
			glyph.AnchorPoint, glyph.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
			session:connect(button.MouseEnter, function()
				button.BackgroundTransparency = 0
			end)
			session:connect(button.MouseLeave, function()
				button.BackgroundTransparency = 1
			end)
			return button
		end
		local previous, following = arrow("chevron-left", 0), arrow("chevron-right", 1)

		local grid = Create.new("Frame", { Name = "Days", Size = UDim2.new(1, 0, 0, cell * 7), LayoutOrder = 1, Parent = popup.frame })
		Create.new("UIGridLayout", {
			CellSize = UDim2.new(1 / 7, 0, 0, cell),
			CellPadding = UDim2.fromOffset(0, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = grid,
		})
		local names = if mondayFirst then { "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" } else { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" }
		for index, name in names do
			Create.new("TextLabel", {
				Text = Strings.get(name),
				TextSize = 12,
				Weight = "bold",
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = index,
				Theme = { TextColor3 = "textMuted" },
				Parent = grid,
			})
		end
		local days = {}
		for index = 1, 42 do
			local button = Create.new("TextButton", {
				Name = "Day",
				TextSize = 13,
				LayoutOrder = 7 + index,
				BackgroundTransparency = 1,
				Theme = { BackgroundColor3 = "accent", TextColor3 = "text" },
				Parent = grid,
			})
			Create.corner(-1, button)
			days[index] = button
		end

		local function fill()
			title.Text = Strings.get(MONTHS[shown.Month]) .. " " .. shown.Year
			local offset = firstColumn(shown.Year, shown.Month, mondayFirst) - 1
			local count = daysIn(shown.Year, shown.Month)
			for index, button in days do
				local day = index - offset
				local inMonth = day >= 1 and day <= count
				button.Visible = inMonth
				button.Text = if inMonth then tostring(day) else ""
				local picked = inMonth and day == value.Day and shown.Month == value.Month and shown.Year == value.Year
				local today = inMonth and day == now.day and shown.Month == now.month and shown.Year == now.year
				button.BackgroundTransparency = if picked then 0 else 1
				Theme.bind(button, "TextColor3", if picked then "onAccent" elseif today then "accent" else "text")
				button.FontFace = Create.font(if picked or today then "bold" else "regular")
			end
		end
		for index, button in days do
			session:connect(button.Activated, function()
				local day = index - (firstColumn(shown.Year, shown.Month, mondayFirst) - 1)
				local picked = copy(value)
				picked.Year, picked.Month, picked.Day = shown.Year, shown.Month, day
				handle:Set(picked)
				if withTime then
					fill()
				else
					popup.close()
				end
			end)
		end
		session:connect(previous.Activated, function()
			shown.Month -= 1
			if shown.Month < 1 then
				shown.Month, shown.Year = 12, shown.Year - 1
			end
			fill()
		end)
		session:connect(following.Activated, function()
			shown.Month += 1
			if shown.Month > 12 then
				shown.Month, shown.Year = 1, shown.Year + 1
			end
			fill()
		end)
		fill()

		if withTime then
			local line = Create.new("Frame", { Name = "Time", Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 2, Parent = popup.frame })
			Create.list(line, "Horizontal", 6, { HorizontalAlignment = Enum.HorizontalAlignment.Center })
			local function field(key, limit, order)
				local box = Create.new("TextBox", {
					Name = key,
					Size = UDim2.fromOffset(52, 30),
					Text = string.format("%02d", value[key]),
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Center,
					LayoutOrder = order,
					Theme = { BackgroundColor3 = "raised", TextColor3 = "text" },
					Parent = line,
				})
				Create.corner(6, box)
				Create.stroke("stroke", box)
				session:connect(box.FocusLost, function()
					local typed = tonumber(box.Text)
					local picked = copy(value)
					if typed then
						picked[key] = math.clamp(math.floor(typed), 0, limit)
					end
					handle:Set(picked)
					box.Text = string.format("%02d", value[key])
				end)
			end
			field("Hour", 23, 1)
			Create.new("TextLabel", { Size = UDim2.fromOffset(6, 30), Text = ":", TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Theme = { TextColor3 = "text" }, Parent = line })
			field("Minute", 59, 3)
		end
	end)

	draw()
	return handle
end

return DatePicker
