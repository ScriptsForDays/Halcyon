local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Icons = require("../Core/Icons")
local Row = require("./Row")
local Theme = require("../Core/Theme")

local Banner = {}

-- A wide card for an announcement or a game's art: a picture (any image
-- source), a title, a line of text and an optional button. Without a
-- picture it sits on a tint of the accent. Options: Title, Text, Image,
-- Height (default 132), Button = { Title, Callback }.
function Banner.new(container, options)
	local row = Row.new(container, options, { bare = true, compact = true })
	local handle, scope = row.handle, row.scope
	local height = math.clamp(tonumber(options.Height) or 132, 72, 320)

	local card = Create.new("Frame", {
		Name = "Banner",
		Size = UDim2.new(1, 0, 0, height),
		ClipsDescendants = true,
		Theme = { BackgroundColor3 = "raised" },
		Parent = row.content,
	})
	Create.corner(10, card)
	local picture
	if options.Image then
		picture = Create.new("ImageLabel", { Name = "Picture", Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Crop, Parent = card })
		Create.corner(10, picture)
		Icons.apply(picture, options.Image)
	else
		-- No picture: a soft run of the accent across the card.
		local tint = Create.new("Frame", { Name = "Tint", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.82, Theme = { BackgroundColor3 = "accent" }, Parent = card })
		Create.corner(10, tint)
		Create.new("UIGradient", {
			Rotation = 20,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.7) }),
			Parent = tint,
		})
	end
	-- The words sit on a shade that darkens toward the bottom, so they read
	-- over any picture.
	local shade = Create.new("Frame", { Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = if picture then 0.15 else 1, ZIndex = 2, Parent = card })
	Create.corner(10, shade)
	Create.new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0.75), NumberSequenceKeypoint.new(1, 0) }),
		Parent = shade,
	})

	local words = Create.new("Frame", {
		Name = "Words",
		Size = UDim2.new(1, -32, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -14),
		ZIndex = 3,
		Parent = card,
	})
	Create.list(words, "Vertical", 2)
	local onPicture = picture ~= nil
	local title = Create.new("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, -120, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		Text = options.Title or "",
		TextSize = 17,
		Weight = "bold",
		ZIndex = 3,
		Parent = words,
	})
	local text = Create.new("TextLabel", {
		Name = "Text",
		Size = UDim2.new(1, -120, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		Text = options.Text or "",
		TextSize = 13,
		LayoutOrder = 1,
		Visible = (options.Text or "") ~= "",
		ZIndex = 3,
		Parent = words,
	})
	if onPicture then
		title.TextColor3 = Color3.new(1, 1, 1)
		text.TextColor3 = Color3.fromRGB(225, 228, 234)
	else
		Theme.bind(title, "TextColor3", "text")
		Theme.bind(text, "TextColor3", "textMuted")
	end

	local button
	if type(options.Button) == "table" then
		local settings = options.Button
		button = Create.new("TextButton", {
			Name = "Button",
			Size = UDim2.fromOffset(0, row.reach + 4),
			AutomaticSize = Enum.AutomaticSize.X,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -14),
			Text = settings.Title or "Open",
			TextSize = 13,
			Weight = "medium",
			ZIndex = 4,
			Theme = { BackgroundColor3 = "accent", TextColor3 = "onAccent" },
			Parent = card,
		})
		Create.corner(8, button)
		Create.padding(button, 14, 0)
		scope:connect(button.Activated, function()
			row.fire(settings.Title)
			Env.call(settings.Title or "Banner", settings.Callback)
		end)
	end

	-- Wide, the button sits to the right of the words. Narrow, it drops
	-- below them and the card grows to fit, so nothing is cut off.
	local function fit()
		local scale = row.library.scale
		local width = card.AbsoluteSize.X / scale
		if width <= 0 then
			return
		end
		local buttonWidth = if button then button.AbsoluteSize.X / scale else 0
		local beside = width - 32 - buttonWidth - 12
		local stacked = button ~= nil and beside < 180
		local room = if button and not stacked then beside else width - 32
		title.Size = UDim2.new(0, room, 0, 0)
		text.Size = UDim2.new(0, room, 0, 0)
		local below = if stacked then button.AbsoluteSize.Y / scale + 10 else 0
		words.Position = UDim2.new(0, 16, 1, -14 - below)
		if button then
			button.AnchorPoint = if stacked then Vector2.new(0, 1) else Vector2.new(1, 1)
			button.Position = if stacked then UDim2.new(0, 16, 1, -14) else UDim2.new(1, -16, 1, -14)
		end
		local needed = math.ceil(16 + words.AbsoluteSize.Y / scale + 14 + below)
		card.Size = UDim2.new(1, 0, 0, math.max(height, needed))
	end
	scope:connect(card:GetPropertyChangedSignal("AbsoluteSize"), fit)
	scope:connect(words:GetPropertyChangedSignal("AbsoluteSize"), fit)
	if button then
		scope:connect(button:GetPropertyChangedSignal("AbsoluteSize"), fit)
	end
	fit()

	function handle:SetTitle(value)
		self.Title = tostring(value)
		title.Text = self.Title
	end

	function handle:SetText(value)
		text.Text = tostring(value or "")
		text.Visible = text.Text ~= ""
	end

	function handle:SetImage(source)
		if picture then
			Icons.apply(picture, source)
		end
	end

	handle.SearchExtra = options.Text or ""
	return handle
end

return Banner
