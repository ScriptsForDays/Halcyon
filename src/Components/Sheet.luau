-- A panel that slides over the page from the window's right edge, for the
-- options of one feature without leaving the tab. It holds sections like a
-- tab does, and element methods on the sheet itself add to its first one.
-- A press on the dimmed page behind it closes it.

local Create = require("../Core/Create")
local Motion = require("../Core/Motion")
local Registry = require("../Elements/Registry")
local Section = require("./Section")

local Sheet = {}
Sheet.__index = function(self, key)
	local method = rawget(Sheet, key)
	if method then
		return method
	end
	-- Element methods (Toggle, Slider, ...) go to the sheet's first section.
	local first = rawget(self, "first")
	if Registry.KindSet[key] then
		return function(_, options)
			if not first then
				first = self:Section({})
				rawset(self, "first", first)
			end
			return first[key](first, options)
		end
	end
	return nil
end

-- Options: Title, Width (default 340).
function Sheet.new(window, options)
	options = options or {}
	local scope = window.scope:child()
	local self = setmetatable({ window = window, library = window.library, scope = scope, IsOpen = false, order = 0 }, Sheet)

	local layer = Create.new("Frame", { Name = "Sheet", Size = UDim2.fromScale(1, 1), ZIndex = 20, Visible = false, Parent = window.body })
	scope:add(layer)
	local scrim = Create.new("TextButton", {
		Name = "Scrim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = layer,
	})
	local width = math.clamp(tonumber(options.Width) or 340, 240, 520)
	local panel = Create.new("Frame", {
		Name = "Panel",
		Size = UDim2.new(0, width, 1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, width, 0, 0),
		ZIndex = 21,
		Theme = { BackgroundColor3 = "background" },
		Parent = layer,
	})
	Create.new("UISizeConstraint", { MaxSize = Vector2.new(width, math.huge), Parent = panel })
	Create.stroke("stroke", panel)
	local head = Create.new("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, 48), ZIndex = 22, Parent = panel })
	Create.padding(head, 16, 0, 8, 0)
	Create.list(head, "Horizontal", 8, { VerticalAlignment = Enum.VerticalAlignment.Center })
	self.titleLabel = Create.new("TextLabel", {
		Name = "Title",
		Size = UDim2.fromScale(0, 1),
		Text = options.Title or "",
		TextSize = 15,
		Weight = "bold",
		ZIndex = 22,
		Theme = { TextColor3 = "text" },
		Parent = head,
	}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	local close = Create.new("TextButton", { Name = "Close", Size = UDim2.fromOffset(36, 36), LayoutOrder = 1, ZIndex = 22, Parent = head })
	Create.corner(8, close)
	local cross = Create.icon("x", 16, "textMuted", close)
	cross.AnchorPoint, cross.Position, cross.ZIndex = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), 22
	local page = Create.new("ScrollingFrame", {
		Name = "Page",
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		ScrollBarThickness = 3,
		ZIndex = 21,
		Parent = panel,
	})
	local inset = Create.new("Frame", { Name = "Inset", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = page })
	Create.padding(inset, 12)
	Create.list(inset, "Vertical", 10)

	-- What a section expects of the tab it sits in.
	self.host = {
		library = window.library,
		window = window,
		scope = scope,
		entries = {},
		sections = {},
		left = inset,
		right = inset,
		sectionStyle = options.SectionStyle,
		order = 0,
	}
	function self.host.nextOrder(host)
		host.order += 1
		return host.order
	end
	function self.host.reflow() end
	self.layer, self.scrim, self.panel, self.width = layer, scrim, panel, width

	scope:connect(scrim.Activated, function()
		self:Close()
	end)
	scope:connect(close.Activated, function()
		self:Close()
	end)
	return self
end

function Sheet:Section(options)
	local section = Section.new(self.host, options or {})
	table.insert(self.host.sections, section)
	return section
end

function Sheet:SetTitle(title)
	self.titleLabel.Text = tostring(title or "")
end

function Sheet:Open()
	if self.IsOpen then
		return
	end
	self.IsOpen = true
	self.layer.Visible = true
	Motion.tween(self.scrim, "base", { BackgroundTransparency = 0.5 })
	Motion.tween(self.panel, "base", { Position = UDim2.new(1, 0, 0, 0) })
end

function Sheet:Close()
	if not self.IsOpen then
		return
	end
	self.IsOpen = false
	Motion.tween(self.scrim, "fast", { BackgroundTransparency = 1 })
	Motion.tween(self.panel, "fast", { Position = UDim2.new(1, self.width, 0, 0) })
	local layer = self.layer
	task.delay(if Motion.reduced then 0 else 0.13, function()
		if not self.IsOpen and not self.scope.cleaned then
			layer.Visible = false
		end
	end)
end

function Sheet:Destroy()
	self.window.scope:release(self.scope)
end

return Sheet
