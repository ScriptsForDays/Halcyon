-- Where ScreenGuis live: the executor's hidden container when it has one,
-- otherwise the local player's PlayerGui, which is also what Studio uses.

local Players = game:GetService("Players")

local Create = require("./Create")
local Env = require("./Env")

local Mount = {}

function Mount.parent()
	if Env.gethui then
		local ok, container = pcall(Env.gethui)
		if ok and typeof(container) == "Instance" then
			return container
		end
	end
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- The shared layer above every window: popups, then dialogs, then toasts.
function Mount.overlay(kit)
	if kit.overlay then
		return kit.overlay
	end
	-- No screen insets: a dialog's scrim has to cover the whole screen,
	-- including the strip behind Roblox's top bar and a phone's notch.
	local gui = Create.new("ScreenGui", {
		Name = "HalcyonOverlay",
		DisplayOrder = kit.displayOrder + 10,
		ScreenInsets = Enum.ScreenInsets.None,
		Parent = Mount.parent(),
	})
	local function layer(name, order)
		return Create.new("Frame", { Name = name, Size = UDim2.fromScale(1, 1), ZIndex = order, Parent = gui })
	end
	local overlay = { gui = gui, popups = layer("Popups", 1), dialogs = layer("Dialogs", 2), toasts = layer("Toasts", 3) }
	kit.overlay = overlay
	kit.scope:add(function()
		gui:Destroy()
		if kit.overlay == overlay then
			kit.overlay = nil
		end
	end)
	return overlay
end

return Mount
