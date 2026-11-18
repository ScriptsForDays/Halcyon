-- The row on a tab or section that opens one of its sub-pages. Made by
-- Tab:Page and Section:Page; the whole row is the button.

local Create = require("../Core/Create")
local Row = require("./Row")
local Theme = require("../Core/Theme")

local PageLink = {}

function PageLink.new(container, options)
	local row = Row.new(container, options, { button = true })
	local handle = row.handle
	local arrow = Create.icon("chevron-right", 16, "textMuted", row.slot)
	row.onHover(function(active)
		Theme.bind(arrow, "ImageColor3", if active then "accent" else "textMuted")
		Theme.bind(row.frame, "BackgroundColor3", if active then "hover" else container.rowRole or "raised")
		row.frame.BackgroundTransparency = if active then 0 elseif container.rowFill then 0 else 1
	end)
	row.scope:connect(row.frame.Activated, function()
		if not handle:IsLocked() and options.Page then
			row.window:SelectTab(options.Page)
			row.fire(options.Page)
		end
	end)

	-- The page this row opens.
	function handle:Get()
		return options.Page
	end

	return handle
end

return PageLink
