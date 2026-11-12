local Create = require("../Core/Create")

local Space = {}

-- Empty room between rows. Options: Height (default 8).
function Space.new(container, options)
	local scope = container.scope:child()
	local frame = Create.new("Frame", {
		Name = "Space",
		Size = UDim2.new(1, 0, 0, tonumber(options.Height) or 8),
		LayoutOrder = container:nextOrder(),
		Parent = container.frame,
	})
	scope:add(frame)
	local handle = { Frame = frame, Title = "", Hidden = false, scope = scope, SearchText = "" }

	function handle:SetVisible(visible)
		self.Hidden = not visible
		frame.Visible = visible
	end

	function handle:Destroy()
		container.scope:release(scope)
	end

	return handle
end

return Space
