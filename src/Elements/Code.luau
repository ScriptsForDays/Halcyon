local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Row = require("./Row")

local MONOSPACE = Font.new("rbxasset://fonts/families/RobotoMono.json")

local Code = {}

-- A block of code with a copy button. Options: Title, Code.
function Code.new(container, options)
	local row = Row.new(container, { Title = options.Title or "Code" }, { bare = true })
	local handle, scope, library = row.handle, row.scope, row.library
	local code = options.Code or ""

	local block = Create.new("Frame", {
		Name = "Code",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Theme = { BackgroundColor3 = row.controlRole },
		Parent = row.content,
	})
	Create.corner(8, block)
	Create.stroke("stroke", block)
	Create.list(block, "Vertical", 0)

	local header = Create.new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 36), Parent = block })
	local caption = Create.new("TextLabel", {
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		Text = handle.Title,
		TextSize = 12,
		Weight = "medium",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = "textMuted" },
		Parent = header,
	})
	local copy = Create.new("TextButton", { Name = "Copy", Size = UDim2.fromOffset(44, 36), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Parent = header })
	local glyph = Create.icon("copy", 14, "textMuted", copy)
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)

	-- Long lines scroll sideways instead of wrapping, so indentation stays readable.
	local scroller = Create.new("ScrollingFrame", {
		Name = "Lines",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		LayoutOrder = 1,
		Parent = block,
	})
	Create.padding(scroller, 12, 0, 12, 12)
	local text = Create.new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		FontFace = MONOSPACE,
		TextSize = 13,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = code,
		Theme = { TextColor3 = "text" },
		Parent = scroller,
	})

	function handle:Get()
		return code
	end

	function handle:Set(newCode)
		code = tostring(newCode)
		text.Text = code
	end

	function handle:SetTitle(newTitle)
		self.Title = newTitle
		caption.Text = newTitle
		self.SearchText = string.lower(newTitle)
	end

	scope:connect(copy.Activated, function()
		if Env.copy(code) then
			library.notify({ Title = "Copied", Content = "The code is on your clipboard.", Kind = "success", Duration = 2 })
		else
			library.notify({ Title = "Copy unavailable", Content = "This executor cannot write to the clipboard.", Kind = "warning" })
		end
	end)

	return handle
end

return Code
