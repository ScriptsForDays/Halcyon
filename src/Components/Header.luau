-- The window's header (kind "Header", chosen with HeaderStyle):
--   Bar       the top bar: picture, title and subtitle, then the buttons
--   Tall      a taller top bar with a large picture and larger titles
--   Wordmark  the hub's logo in place of the title text
--   Sidebar   no top bar: the logo heads the sidebar with search under it,
--             and the window's buttons sit small in the top-right corner
-- The logo comes from Logo: an image (asset id, URL, file or icon name), a
-- table { Image, Text, Icon, Height, Width }, or false for none. Without an
-- image the title is drawn large beside the hub's icon, so it works in
-- Studio and on executors without getcustomasset.

local Assets = require("../Core/Assets")
local Create = require("../Core/Create")
local Drag = require("../Core/Drag")
local Hairline = require("../Core/Hairline")
local Icons = require("../Core/Icons")
local Styles = require("../Core/Styles")
local Theme = require("../Core/Theme")

Styles.register("Header", "Bar", { height = 48 })
Styles.register("Header", "Tall", { height = 64, image = 44, icon = 26, title = 16, subtitle = 13 })
Styles.register("Header", "Wordmark", { height = 56, wordmark = true })
Styles.register("Header", "Sidebar", { height = 48, sidebar = true })

-- The strip along the top of the page that holds the buttons when the
-- sidebar carries the logo.
local STRIP = 40

local Header = { STRIP = STRIP }

-- What the logo is made of, or nil when the hub turned it off.
function Header.logo(window)
	local value = window.options.Logo
	if value == false then
		return nil
	end
	if type(value) == "string" or type(value) == "number" then
		return { image = value }
	end
	local logo = if type(value) == "table" then value else {}
	local icon = logo.Icon
	if icon == nil then
		icon = window.Icon
	end
	return {
		image = logo.Image,
		text = logo.Text or window.Title,
		icon = icon,
		height = tonumber(logo.Height),
		width = tonumber(logo.Width),
	}
end

-- `large` is the sidebar's size; otherwise the logo fits a top bar. A logo
-- drawn as text returns its label, so SetTitle can still change it.
function Header.drawLogo(window, logo, parent, large)
	if logo.image then
		local image = Create.new("ImageLabel", {
			Name = "Logo",
			Size = if large then UDim2.new(1, 0, 0, logo.height or 56) else UDim2.fromOffset(logo.width or 150, logo.height or 30),
			ScaleType = Enum.ScaleType.Fit,
			Parent = parent,
		})
		-- An icon name takes the accent; a picture keeps its own colours.
		if Assets.kind(logo.image) == nil then
			Theme.bind(image, "ImageColor3", "accent")
		end
		Icons.apply(image, logo.image)
		return nil
	end
	local row = Create.new("Frame", {
		Name = "Logo",
		Size = if large then UDim2.new(1, 0, 0, 32) else UDim2.fromOffset(0, 28),
		AutomaticSize = if large then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
		Parent = parent,
	})
	Create.list(row, "Horizontal", if large then 10 else 8)
	if logo.icon then
		Create.icon(logo.icon, if large then 28 else 22, "accent", row)
	end
	local label = Create.new("TextLabel", {
		Name = "Title",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = if large then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
		Text = logo.text or window.Title,
		TextSize = if large then 22 else 19,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Weight = "bold",
		LayoutOrder = 1,
		Theme = { TextColor3 = "text" },
		Parent = row,
	})
	if large then
		Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = label })
	end
	return label
end

-- The Wordmark header's brand: the logo, then the version tag. The title
-- and subtitle labels still exist so SetTitle and SetSubtitle keep working.
function Header.wordmark(window, brand)
	local logo = Header.logo(window) or { text = window.Title, icon = window.Icon }
	local label = Header.drawLogo(window, logo, brand, false)
	window.titleLabel = label or Create.new("TextLabel", { Name = "Title", Text = window.Title, Visible = false, Parent = brand })
	window.subtitleLabel = Create.new("TextLabel", { Name = "Subtitle", Text = window.Subtitle or "", Visible = false, Parent = brand })
	return logo
end

-- The searching box, in the top bar or the sidebar. Typing in either keeps
-- the query, so switching between them carries it across.
function Header.searchBox(window, scope, parent, size)
	local search = Create.new("Frame", { Name = "Search", Size = size, Theme = { BackgroundColor3 = "raised" }, Parent = parent })
	Create.corner(8, search)
	local glass = Create.icon("search", 14, "textMuted", search)
	glass.AnchorPoint = Vector2.new(0, 0.5)
	glass.Position = UDim2.new(0, 10, 0.5, 0)
	local box = Create.new("TextBox", {
		Name = "Query",
		Position = UDim2.fromOffset(32, 0),
		Size = UDim2.new(1, -38, 1, 0),
		PlaceholderText = "Search",
		TextSize = 13,
		ClipsDescendants = true,
		Text = window.searchText or "",
		Theme = { TextColor3 = "text" },
		Parent = search,
	})
	scope:connect(box:GetPropertyChangedSignal("Text"), function()
		window.searchText = box.Text
		window:applySearch(box.Text)
	end)
	return search, box
end

-- The top of the sidebar in the Sidebar header: the logo (which also drags
-- the window), a line, then search.
function Header.sidebarTop(window, scope, column)
	local logo = Header.logo(window)
	if logo then
		local box = Create.new("Frame", { Name = "SidebarBrand", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = -3, Parent = column })
		Create.padding(box, 16, 18, 14, 14)
		Create.list(box, "Vertical", 4)
		local label = Header.drawLogo(window, logo, box, true)
		if label then
			window.titleLabel = label
		end
		if window.Subtitle and not logo.image then
			window.subtitleLabel = Create.new("TextLabel", {
				Name = "Subtitle",
				Size = UDim2.new(1, 0, 0, 16),
				Text = window.Subtitle,
				TextSize = 12,
				TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = 1,
				Theme = { TextColor3 = "textMuted" },
				Parent = box,
			})
		end
		Drag.move(scope, box, window.root, window:dragOptions())
		Hairline.new("X", "stroke", { LayoutOrder = -2, Parent = column })
	end
	if window.options.Search ~= false then
		local area = Create.new("Frame", { Name = "SearchArea", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = -1, Parent = column })
		Create.padding(area, 10, 10, 10, 2)
		window.searchFrame, window.searchBox = Header.searchBox(window, scope, area, UDim2.new(1, 0, 0, 34))
	end
end

-- Moves the window between the top bar and the sidebar header. The sidebar
-- carries the logo only while the full sidebar shows; with a rail, a strip
-- of tabs or a narrow window the top bar comes back.
function Header.apply(window, sidebar)
	window.sidebarHeader = sidebar
	local topbar, height = window.topbar, window.topbarHeight
	if sidebar then
		local lane = window:lane("Sidebar")
		topbar.Position = UDim2.fromOffset(lane, 0)
		topbar.Size = UDim2.new(1, -lane, 0, STRIP)
		window.body.Position = UDim2.fromOffset(0, 0)
		window.body.Size = UDim2.fromScale(1, 1)
	else
		topbar.Position = UDim2.fromOffset(0, 0)
		topbar.Size = UDim2.new(1, 0, 0, height)
		window.body.Position = UDim2.fromOffset(0, height)
		window.body.Size = UDim2.new(1, 0, 1, -height)
		window.searchFrame, window.searchBox = window.topbarSearch, window.topbarBox
		window.titleLabel, window.subtitleLabel = window.topbarTitle, window.topbarSubtitle
		if window.topbarBox.Text ~= (window.searchText or "") then
			window.topbarBox.Text = window.searchText or ""
		end
	end
	window.brand.Visible = not sidebar
	window.topbarSearch.Visible = not sidebar and window.options.Search ~= false
	window.chipHolder.Visible = not sidebar
	if window.dots then
		window.dots.Parent = if sidebar then window.topbarActions else window.brand
	end
end

return Header
