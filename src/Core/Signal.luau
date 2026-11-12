-- A minimal event. Handlers run in their own threads, so one that errors or
-- yields cannot stop the others.

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ list = {} }, Signal)
end

function Signal:Connect(handler)
	local list = self.list
	local connection = { Connected = true, handler = handler }

	function connection.Disconnect()
		if not connection.Connected then
			return
		end
		connection.Connected = false
		local index = table.find(list, connection)
		if index then
			table.remove(list, index)
		end
	end

	table.insert(list, connection)
	return connection
end

function Signal:Once(handler)
	local connection
	connection = self:Connect(function(...)
		connection.Disconnect()
		handler(...)
	end)
	return connection
end

function Signal:Fire(...)
	for _, connection in table.clone(self.list) do
		if connection.Connected then
			task.spawn(connection.handler, ...)
		end
	end
end

function Signal:Destroy()
	for _, connection in self.list do
		connection.Connected = false
	end
	table.clear(self.list)
end

return Signal
