local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Icons = require("../Core/Icons")
local Row = require("./Row")
local Theme = require("../Core/Theme")

local Link = {}

-- The site a link points at, for the line under its title.
local function domain(url)
	return string.match(url, "^%a[%w+.-]*://([^/?#]+)") or url
end

-- A link the player can copy: a Discord invite, a website, a key page.
-- Roblox can't open a browser, so pressing it copies the address and says
-- so. Options: Url, Icon (before the title, like any row). Without a
-- clipboard the address shows in a box to select instead.
function Link.new(container, options)
	if type(options.Description) ~= "string" then
		options.Description = domain(tostring(options.Url or ""))
	end
	local row = Row.new(container, options, { button = true })
	local handle, scope = row.handle, row.scope
	local url = tostring(options.Url or "")

	local mark = Create.new("Frame", { Name = "Mark", Size = UDim2.fromOffset(row.reach, row.reach), Theme = { BackgroundColor3 = row.controlRole }, Parent = row.slot })
	Create.corner(8, mark)
	local glyph = Create.icon("copy", 15, "textMuted", mark)
	glyph.AnchorPoint, glyph.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)

	local box
	local function fallback()
		if box then
			box.Visible = true
			return
		end
		local below = row.belowTitle()
		box = Create.new("TextBox", {
			Name = "Address",
			Size = UDim2.new(1, 0, 0, 30),
			Text = url,
			TextSize = 12,
			TextEditable = false,
			ClearTextOnFocus = false,
			Theme = { BackgroundColor3 = row.controlRole, TextColor3 = "text" },
			Parent = below,
		})
		Create.corner(6, box)
		Create.padding(box, 10, 0)
	end

	local resetting
	scope:connect(row.frame.Activated, function()
		if Env.copy(url) then
			Icons.apply(glyph, "check")
			Theme.bind(glyph, "ImageColor3", "success")
			if resetting then
				task.cancel(resetting)
			end
			resetting = task.delay(1.5, function()
				resetting = nil
				if not scope.cleaned then
					Icons.apply(glyph, "copy")
					Theme.bind(glyph, "ImageColor3", "textMuted")
				end
			end)
			row.fire(url)
		else
			fallback()
		end
	end)
	row.onHover(function(on)
		Theme.bind(mark, "BackgroundColor3", if on then "hover" else row.controlRole)
	end)

	function handle:Get()
		return url
	end

	function handle:Set(value)
		url = tostring(value or "")
		handle:SetDescription(domain(url))
		if box then
			box.Text = url
		end
	end

	handle.SearchExtra = url
	return handle
end

return Link
