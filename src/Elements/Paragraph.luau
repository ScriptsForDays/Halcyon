local Row = require("./Row")

local Paragraph = {}

-- A title with wrapped text under it. Options: Title, Content, Icon.
function Paragraph.new(container, options)
	local row = Row.new(container, { Title = options.Title, Description = options.Content, Icon = options.Icon })
	local handle = row.handle

	-- Set({ Title = ..., Content = ... }) or Set("content").
	function handle:Set(value)
		if type(value) == "table" then
			if value.Title then
				self:SetTitle(value.Title)
			end
			self:SetDescription(value.Content)
		else
			self:SetDescription(tostring(value))
		end
	end

	return handle
end

return Paragraph
