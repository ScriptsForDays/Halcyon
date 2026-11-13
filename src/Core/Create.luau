-- Instance construction with the defaults every Halcyon instance shares.
--
--   Create.new("Frame", { Size = ..., Theme = { BackgroundColor3 = "card" } }, { child, child })
--
-- `Theme` binds colour properties to palette roles, `Weight` picks the font
-- weight for text, and `Icon` draws a named icon on an image.

local TextService = game:GetService("TextService")

local Icons = require("./Icons")
local Theme = require("./Theme")
local Tokens = require("./Tokens")

local TEXT = { TextLabel = true, TextButton = true, TextBox = true }
local IMAGE = { ImageLabel = true, ImageButton = true }
local VISUAL = { Frame = true, ScrollingFrame = true, CanvasGroup = true, ViewportFrame = true }
local NOT_PROPERTIES = { Theme = true, Weight = true, Icon = true, Parent = true }
-- One step heavier than the names suggest: thin strokes wash out over a
-- bright or busy game, and this is text people read while playing.
local WEIGHTS = { regular = Enum.FontWeight.Medium, medium = Enum.FontWeight.SemiBold, bold = Enum.FontWeight.Bold }

local Create = {
	-- Inter, from the Creator Store: drawn for interfaces, with open
	-- letterforms that stay clear at 12 px.
	family = "rbxassetid://12187365364",
	fonts = {},
}

function Create.font(weight)
	local key = weight or "regular"
	local font = Create.fonts[key]
	if not font then
		font = Font.new(Create.family, WEIGHTS[key] or WEIGHTS.regular)
		Create.fonts[key] = font
	end
	return font
end

-- Accepts a font family content string, a Font or an Enum.Font. Applies to
-- everything created afterwards.
function Create.setFamily(font)
	local kind = typeof(font)
	if kind == "EnumItem" then
		font = Font.fromEnum(font).Family
	elseif kind == "Font" then
		font = font.Family
	elseif kind ~= "string" then
		return false
	end
	Create.family = font
	table.clear(Create.fonts)
	return true
end

-- The font is an asset, so a window can draw before it has downloaded.
-- Roblox then draws a stand-in face with other measurements, and every
-- label jumps to its real size a moment later. `preload` starts fetching
-- each weight; `waitForFont` yields until they have arrived, or until
-- `limit` seconds pass.
local waiting = {}

function Create.preload()
	local family = Create.family
	if Create.loaded == family or Create.loading == family then
		return
	end
	Create.loading = family
	task.spawn(function()
		for _, weight in WEIGHTS do
			-- GetTextBoundsAsync yields until the font is ready. Where it is
			-- missing (tests, the web demo) there is nothing to wait for.
			pcall(function()
				local params = Instance.new("GetTextBoundsParams")
				params.Text = "Halcyon"
				params.Font = Font.new(family, weight)
				params.Size = 14
				TextService:GetTextBoundsAsync(params)
			end)
		end
		if Create.loading ~= family then
			return
		end
		Create.loaded, Create.loading = family, nil
		local threads = table.clone(waiting)
		table.clear(waiting)
		for _, thread in threads do
			task.spawn(thread)
		end
	end)
end

function Create.waitForFont(limit)
	Create.preload()
	if Create.loaded == Create.family then
		return
	end
	local thread = coroutine.running()
	table.insert(waiting, thread)
	task.delay(limit, function()
		local index = table.find(waiting, thread)
		if index then
			table.remove(waiting, index)
			task.spawn(thread)
		end
	end)
	coroutine.yield()
end

function Create.new(className: string, properties: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	local themed = properties.Theme
	local filled = properties.BackgroundColor3 ~= nil or (themed ~= nil and themed.BackgroundColor3 ~= nil)

	if TEXT[className] or IMAGE[className] or VISUAL[className] then
		instance.BorderSizePixel = 0
		instance.BackgroundTransparency = if filled then 0 else 1
	end
	if TEXT[className] then
		instance.FontFace = Create.font(properties.Weight)
		instance.TextSize = 14
		instance.Text = ""
		instance.TextXAlignment = if className == "TextButton" then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
		if className == "TextBox" then
			instance.ClearTextOnFocus = false
			Theme.bind(instance, "PlaceholderColor3", "textMuted")
		end
	end
	if className == "TextButton" or className == "ImageButton" then
		instance.AutoButtonColor = false
	end
	if IMAGE[className] then
		instance.ScaleType = Enum.ScaleType.Fit
	elseif className == "ScrollingFrame" then
		instance.ScrollBarThickness = 3
		instance.CanvasSize = UDim2.new(0, 0, 0, 0)
		instance.AutomaticCanvasSize = Enum.AutomaticSize.Y
		instance.ScrollingDirection = Enum.ScrollingDirection.Y
		Theme.bind(instance, "ScrollBarImageColor3", "stroke")
	elseif className == "ScreenGui" then
		instance.ResetOnSpawn = false
		instance.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		instance.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	elseif className == "UIStroke" then
		instance.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end

	for key, value in properties do
		if not NOT_PROPERTIES[key] then
			instance[key] = value
		end
	end
	-- The TextSize setting scales every size a component asks for.
	if TEXT[className] and Tokens.textScale ~= 1 then
		instance.TextSize = Tokens.text(instance.TextSize)
	end
	if themed then
		for property, role in themed do
			Theme.bind(instance, property, role)
		end
	end
	if properties.Icon then
		Icons.apply(instance, properties.Icon)
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	instance.Parent = properties.Parent
	return instance
end

-- A radius of -1 rounds fully, for pills and circles. The Radius setting
-- scales every other radius.
function Create.corner(radius, parent)
	local base = radius
	radius = Tokens.corner(radius)
	local corner = Create.new("UICorner", { CornerRadius = if radius < 0 then UDim.new(1, 0) else UDim.new(0, radius), Parent = parent })
	-- Kept so a later Corners setting can rescale it.
	corner:SetAttribute("HalcyonRadius", base)
	return corner
end

function Create.stroke(role, parent, thickness)
	return Create.new("UIStroke", { Thickness = thickness or 1, Theme = { Color = role }, Parent = parent })
end

-- Missing sides repeat the ones given, as in CSS: one value pads all four.
function Create.padding(parent, left, top, right, bottom)
	top = top or left
	return Create.new("UIPadding", {
		PaddingLeft = UDim.new(0, left),
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right or left),
		PaddingBottom = UDim.new(0, bottom or top),
		Parent = parent,
	})
end

function Create.list(parent, direction, gap, properties)
	local layout = Create.new("UIListLayout", {
		FillDirection = Enum.FillDirection[direction],
		Padding = UDim.new(0, gap or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = if direction == "Horizontal" then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top,
	})
	if properties then
		for key, value in properties do
			layout[key] = value
		end
	end
	layout.Parent = parent
	return layout
end

function Create.icon(name, size, role, parent)
	return Create.new("ImageLabel", {
		Name = "Icon",
		Size = UDim2.fromOffset(size, size),
		Icon = name,
		Theme = { ImageColor3 = role },
		Parent = parent,
	})
end

-- Sets a scrolling box's height from what it holds, up to `limit`, past
-- which it scrolls. `source` is the frame inside the box or its list
-- layout. AutomaticSize on the ScrollingFrame would look like the same
-- thing, but Roblox then sizes the auto-sized frames around it as if their
-- padding were missing, and a centred row pushes its title up out of place.
function Create.fitHeight(box, source, limit, library, scope)
	local layout = source.ClassName == "UIListLayout"
	local function fit()
		local measured = if layout then source.AbsoluteContentSize.Y else source.AbsoluteSize.Y
		local height = math.ceil(measured / library.scale)
		box.Size = UDim2.new(box.Size.X.Scale, box.Size.X.Offset, 0, math.min(height, limit))
	end
	scope:connect(source:GetPropertyChangedSignal(if layout then "AbsoluteContentSize" else "AbsoluteSize"), fit)
	fit()
end

return Create
