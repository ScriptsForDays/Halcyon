-- Key combinations, a button's own key, exclusive and confirmed toggles,
-- and inputs that refuse a value with a reason.

local window = Halcyon:CreateWindow({ Title = "Controls", Folder = "ControlPlus", SavePreferences = false })
local tab = window:Tab({ Title = "Combat" })
local section = tab:Section({ Title = "Main" })
Stub.flush()

-- Keybind with Modifiers: Ctrl+F only fires with Ctrl held.
local fired = 0
local combo = section:Keybind({ Title = "Panic", Flag = "Panic", Modifiers = true, Default = "Ctrl+F", Callback = function()
	fired += 1
end })
Stub.flush()
local value = combo:Get()
Stub.check(type(value) == "table" and value.Key == Enum.KeyCode.F and value.Ctrl and not value.Shift, "a text default becomes { Key, Ctrl, Shift, Alt }")
Stub.check(string.find(Stub.byName(combo.Frame, "Key").Text, "Ctrl + F", 1, true) ~= nil, "the chip reads Ctrl + F")
Stub.key(Enum.KeyCode.F)
Stub.equal(fired, 0, "F alone does nothing")
Stub.held = { [Enum.KeyCode.LeftControl] = true }
Stub.key(Enum.KeyCode.F)
Stub.equal(fired, 1, "Ctrl+F presses it")
Stub.held = { [Enum.KeyCode.LeftControl] = true, [Enum.KeyCode.LeftShift] = true }
Stub.key(Enum.KeyCode.F)
Stub.equal(fired, 1, "extra modifiers don't match")
Stub.held = nil
Stub.equal(combo:Encode(), "Ctrl+F", "saved as text")

-- Rebinding records the modifiers held with the next key.
Stub.click(Stub.byName(combo.Frame, "Key"))
Stub.held = { [Enum.KeyCode.LeftShift] = true }
Stub.key(Enum.KeyCode.LeftShift)
Stub.key(Enum.KeyCode.G)
Stub.held = nil
Stub.flush()
value = combo:Get()
Stub.check(value.Key == Enum.KeyCode.G and value.Shift and not value.Ctrl, "a modifier then a key binds the combination")

-- Configs keep combinations.
Stub.check(window:SaveConfig("keys"), "saved")
combo:Set(nil)
Stub.check(window:LoadConfig("keys"), "loaded")
value = combo:Get()
Stub.check(value and value.Key == Enum.KeyCode.G and value.Shift, "the combination comes back from a config")

-- A button's own key.
local pressed = 0
local rejoin = section:Button({ Title = "Rejoin", Keybind = { Default = Enum.KeyCode.J, Flag = "RejoinKey" }, Callback = function()
	pressed += 1
end })
Stub.flush()
Stub.check(rejoin.Keybind ~= nil and Stub.byName(rejoin.Frame, "Key") ~= nil, "Keybind puts a key chip on the button row")
Stub.key(Enum.KeyCode.J)
Stub.equal(pressed, 1, "the key presses the button")
Stub.check(window.Flags.RejoinKey ~= nil, "the key has its own flag")

-- Exclusive toggles.
local legit = section:Toggle({ Title = "Legit aim", Exclusive = "aim" })
local rage = section:Toggle({ Title = "Rage aim", Exclusive = "aim" })
legit:Set(true)
rage:Set(true)
Stub.check(rage:Get() and not legit:Get(), "turning one on turns the other off")
rage:Set(false)
Stub.check(not legit:Get() and not rage:Get(), "both can be off")

-- Confirm asks before turning on from the row, never before turning off.
local risky = section:Toggle({ Title = "Kill aura", Confirm = "Other players may report you." })
Stub.click(risky.Frame)
Stub.flush()
Stub.equal(risky:Get(), false, "a press asks first")
local confirm = Stub.find(game:GetService("Players").LocalPlayer.PlayerGui, function(instance)
	return instance.Text == "Turn on"
end)
Stub.check(confirm ~= nil, "the dialog offers Turn on")
Stub.click(confirm)
Stub.flush()
Stub.equal(risky:Get(), true, "confirming turns it on")
Stub.click(risky.Frame)
Stub.flush()
Stub.equal(risky:Get(), false, "turning off doesn't ask")

-- Validate refuses a value and says why.
local name = section:Input({ Title = "Target", Default = "", Validate = function(text)
	if #text < 3 then
		return false, "Use at least 3 letters."
	end
	return true
end })
name:Set("ab")
Stub.equal(name:Get(), "", "a refused value leaves the old one")
local message = Stub.byName(name.Frame, "InputError")
Stub.check(message ~= nil and message.Visible and message.Text == "Use at least 3 letters.", "the reason shows under the field")
name:Set("Builderman")
Stub.equal(name:Get(), "Builderman", "a good value is taken")
Stub.check(not message.Visible, "and the reason goes away")
name:SetError("That player left.")
Stub.check(message.Visible and message.Text == "That player left.", "SetError shows the hub's own message")
name:SetError(nil)
Stub.check(not message.Visible, "SetError(nil) clears it")
window:Unload()
