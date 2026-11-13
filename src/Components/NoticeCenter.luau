-- The bell in the window's top bar (NotificationCenter = true). Its count is
-- the notices shown since the player last looked; pressing it lists them,
-- newest first, with a button that clears the list.

local Create = require("../Core/Create")
local Motion = require("../Core/Motion")
local Notifications = require("./Notifications")
local Popup = require("./Popup")
local Theme = require("../Core/Theme")

local ICONS = { info = "info", success = "circle-check", warning = "triangle-alert", danger = "circle-alert" }
local LIST_HEIGHT = 320

local NoticeCenter = {}

-- "now", "4m", "2h" or "3d": how long ago a notice arrived.
function NoticeCenter.ago(seconds)
	if seconds < 60 then
		return "now"
	elseif seconds < 3600 then
		return `{math.floor(seconds / 60)}m`
	elseif seconds < 86400 then
		return `{math.floor(seconds / 3600)}h`
	end
	return `{math.floor(seconds / 86400)}d`
end

local function entryRow(entry, parent, order)
	local row = Create.new("Frame", { Name = "Entry", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = parent })
	Create.padding(row, 8, 8)
	Create.list(row, "Horizontal", 10, { VerticalAlignment = Enum.VerticalAlignment.Top })
	Create.icon(ICONS[entry.kind] or "info", 16, if ICONS[entry.kind] then entry.kind else "info", row)
	local text = Create.new("Frame", { Name = "Text", AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = row }, {
		Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
	})
	Create.list(text, "Vertical", 2)
	Create.new("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 13,
		Weight = "medium",
		Text = entry.title,
		Theme = { TextColor3 = "text" },
		Parent = text,
	})
	if entry.content ~= "" then
		Create.new("TextLabel", {
			Name = "Content",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 12,
			LayoutOrder = 1,
			Text = entry.content,
			Theme = { TextColor3 = "textMuted" },
			Parent = text,
		})
	end
	Create.new("TextLabel", {
		Name = "Time",
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 11,
		LayoutOrder = 2,
		Text = NoticeCenter.ago(os.time() - entry.at),
		Theme = { TextColor3 = "textMuted" },
		Parent = row,
	})
end

local function open(window, anchor, refreshBadge)
	local log = Notifications.history(window.library)
	local popup = Popup.toggle(window.library, anchor, { Width = 300 })
	if not popup then
		return
	end
	log.unread = 0
	refreshBadge()

	local head = Create.new("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, 30), Parent = popup.frame })
	Create.padding(head, 8, 0, 4, 0)
	Create.new("TextLabel", {
		Name = "Title",
		Size = UDim2.fromScale(0.6, 1),
		Text = "Notices",
		TextSize = 14,
		Weight = "bold",
		Theme = { TextColor3 = "text" },
		Parent = head,
	})
	local clear = Create.new("TextButton", {
		Name = "Clear",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Text = "Clear all",
		TextSize = 12,
		Weight = "medium",
		Theme = { TextColor3 = "textMuted" },
		Parent = head,
	})
	Create.padding(clear, 6, 0)

	local list = Create.new("ScrollingFrame", {
		Name = "List",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		LayoutOrder = 1,
		Parent = popup.frame,
	})
	Create.fitHeight(list, Create.list(list, "Vertical", 0), LIST_HEIGHT, window.library, popup.scope)

	local function fill()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if #log.entries == 0 then
			Create.new("TextLabel", {
				Name = "Empty",
				Size = UDim2.new(1, 0, 0, 56),
				Text = "No notices yet",
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Center,
				Theme = { TextColor3 = "textMuted" },
				Parent = list,
			})
		else
			for index, entry in log.entries do
				entryRow(entry, list, index)
			end
		end
		clear.Visible = #log.entries > 0
	end
	fill()
	popup.scope:connect(clear.Activated, function()
		table.clear(log.entries)
		log.unread = 0
		refreshBadge()
		fill()
	end)
	popup.scope:connect(clear.MouseEnter, function()
		Theme.bind(clear, "TextColor3", "text")
	end)
	popup.scope:connect(clear.MouseLeave, function()
		Theme.bind(clear, "TextColor3", "textMuted")
	end)
	-- Keeps the open list current as notices come in.
	popup.scope:connect(log.Added, function()
		log.unread = 0
		refreshBadge()
		fill()
	end)
end

-- Puts the bell among the window's top bar buttons. Returns the button.
function NoticeCenter.build(window)
	local log = Notifications.history(window.library)
	local button
	local glyph = window.topbarAction("bell", 1.2, function()
		NoticeCenter.open(window, button)
	end)
	button = glyph.Parent
	button.Name = "Notices"
	local badge = Create.new("TextLabel", {
		Name = "Unread",
		Size = UDim2.fromOffset(0, 14),
		AutomaticSize = Enum.AutomaticSize.X,
		-- Its bottom-left corner sits on the bell's top-right corner, where the
		-- bell has no ink, so the count never covers the icon.
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, 5, 0.5, -4),
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Center,
		Weight = "bold",
		ZIndex = 3,
		Visible = false,
		Theme = { BackgroundColor3 = "accent", TextColor3 = "onAccent" },
		Parent = button,
	})
	Create.corner(-1, badge)
	-- One digit plus this padding is a 14 px circle; more digits grow it into
	-- a pill. A minimum-size constraint would be applied before the padding
	-- and leave a single digit in a wide bubble.
	Create.padding(badge, 5, 0)
	local function refresh()
		badge.Visible = log.unread > 0
		badge.Text = if log.unread > 99 then "99+" else tostring(log.unread)
	end
	window.noticeBadge = refresh
	window.scope:connect(log.Added, function()
		refresh()
		if not Motion.reduced and badge.Visible then
			badge.Size = UDim2.fromOffset(0, 10)
			Motion.tween(badge, "spring", { Size = UDim2.fromOffset(0, 14) })
		end
	end)
	refresh()
	window.noticeButton = button
	return button
end

function NoticeCenter.open(window, anchor)
	open(window, anchor or window.noticeButton, window.noticeBadge or function() end)
end

return NoticeCenter
