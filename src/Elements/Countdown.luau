local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Row = require("./Row")
local Theme = require("../Core/Theme")

local Countdown = {}

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	local hours, minutes = seconds // 3600, (seconds // 60) % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, seconds % 60)
	end
	return string.format("%d:%02d", minutes, seconds % 60)
end

-- Time left until something the hub knows about: a boss spawn, a cooldown,
-- a key's expiry. Options: Seconds (from now) or Ends (an os.time() value),
-- Format (a function from seconds left to text), Done (text once it ends),
-- Callback (runs once at zero).
function Countdown.new(container, options)
	local row = Row.new(container, options)
	local handle, scope = row.handle, row.scope
	-- Seconds left, counted down by the waits themselves.
	local remaining
	local generation = 0

	local readout = Create.new("TextLabel", {
		Name = "Time",
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 14,
		Weight = "bold",
		Theme = { TextColor3 = "text" },
		Parent = row.slot,
	})

	local function text(left)
		if left <= 0 and options.Done then
			return tostring(options.Done)
		end
		if type(options.Format) == "function" then
			local ok, shown = pcall(options.Format, left)
			if ok and shown ~= nil then
				return tostring(shown)
			end
		end
		return clock(left)
	end

	-- One wait per second, and only while counting; nothing runs once it ends.
	local function run()
		generation += 1
		local mine = generation
		task.spawn(function()
			while mine == generation and not scope.cleaned do
				local left = math.max(math.ceil(remaining or 0), 0)
				readout.Text = text(left)
				Theme.bind(readout, "TextColor3", if remaining and left <= 10 and left > 0 then "warning" else "text")
				if not remaining or left <= 0 then
					if remaining then
						remaining = nil
						Env.call(handle.Title, options.Callback)
						handle.Changed:Fire(0)
					end
					return
				end
				local waited = task.wait(math.min(1, remaining))
				if mine == generation and remaining then
					remaining -= waited
				end
			end
		end)
	end

	function handle:Get()
		return if remaining then math.max(0, math.ceil(remaining)) else 0
	end

	-- Starts again from `seconds` (or stops when nil or 0).
	function handle:Set(seconds)
		seconds = tonumber(seconds)
		remaining = if seconds and seconds > 0 then seconds else nil
		run()
	end

	function handle:SetEnd(timestamp)
		timestamp = tonumber(timestamp)
		remaining = if timestamp and timestamp > os.time() then timestamp - os.time() else nil
		run()
	end

	if options.Ends then
		handle:SetEnd(options.Ends)
	else
		handle:Set(options.Seconds)
	end
	return handle
end

return Countdown
