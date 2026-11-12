-- Ownership. Everything a window, tab or element creates goes into a Scope,
-- and one clean() releases it all, newest first.

local Scope = {}
Scope.__index = Scope

local function release(item)
	local kind = typeof(item)
	if kind == "function" then
		item()
	elseif kind == "thread" then
		-- A thread cannot cancel itself; a timer that triggers its own cleanup just returns.
		if coroutine.running() ~= item then
			pcall(task.cancel, item)
		end
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "table" then
		if item.clean then
			item:clean()
		elseif item.Destroy then
			item:Destroy()
		elseif item.Disconnect then
			item.Disconnect()
		end
	end
end

function Scope.new()
	return setmetatable({ items = {}, cleaned = false }, Scope)
end

function Scope:add(item)
	if self.cleaned then
		release(item)
	else
		table.insert(self.items, item)
	end
	return item
end

function Scope:connect(signal, handler)
	return self:add(signal:Connect(handler))
end

function Scope:child()
	return self:add(Scope.new())
end

-- Releases one item now and stops tracking it, so short-lived things such as
-- popups do not pile up in a long-lived scope.
function Scope:release(item)
	local index = table.find(self.items, item)
	if index then
		table.remove(self.items, index)
	end
	release(item)
end

function Scope:clean()
	if self.cleaned then
		return
	end
	self.cleaned = true
	local items = self.items
	for index = #items, 1, -1 do
		local item = items[index]
		items[index] = nil
		release(item)
	end
end

return Scope
