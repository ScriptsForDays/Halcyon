-- Values without callbacks, resetting, reading and writing every flag at
-- once, undo, share codes, per-game configs, and callbacks that yield or fail.

local window = Halcyon:CreateWindow({ Title = "Values", Folder = "ValueHub", SavePreferences = false })
local tab = window:Tab({ Title = "Farm" })
local section = tab:Section({ Title = "Main" })

local flyCalls = {}
local fly = section:Toggle({ Title = "Fly", Flag = "Fly", Callback = function(on)
	table.insert(flyCalls, on)
end })
local speedCalls = 0
local speed = section:Slider({ Title = "Speed", Flag = "Speed", Min = 0, Max = 100, Default = 40, Callback = function()
	speedCalls += 1
end })
local mode = section:Dropdown({ Title = "Mode", Flag = "Mode", Values = { "Legit", "Rage" }, Default = "Legit" })
local tint = section:ColorPicker({ Title = "Tint", Flag = "Tint", Default = Color3.fromRGB(10, 20, 30) })
Stub.flush()

-- SetSilent changes the value and Changed, not the Callback.
local changed = 0
fly.Changed:Connect(function()
	changed += 1
end)
fly:SetSilent(true)
Stub.flush()
Stub.equal(fly:Get(), true, "SetSilent sets the value")
Stub.equal(#flyCalls, 0, "SetSilent skips the Callback")
Stub.equal(changed, 1, "SetSilent still fires Changed")
fly:Set(false)
Stub.equal(#flyCalls, 1, "Set after SetSilent runs the Callback again")

-- Defaults and Reset.
Stub.equal(speed:GetDefault(), 40, "GetDefault gives the starting value")
speed:Set(90)
speed:Reset()
Stub.equal(speed:Get(), 40, "Reset puts the starting value back")

-- Every flag at once.
local values = window:GetValues()
Stub.equal(values.Speed, 40, "GetValues reads each flag")
Stub.equal(values.Mode, "Legit", "GetValues reads dropdowns")
local before = speedCalls
window:SetValues({ Speed = 70, Mode = "Rage", Missing = 1 }, true)
Stub.equal(speed:Get(), 70, "SetValues sets by flag")
Stub.equal(mode:Get(), "Rage", "SetValues sets several")
Stub.equal(speedCalls, before, "SetValues with silent skips callbacks")
window:ResetValues()
Stub.equal(speed:Get(), 40, "ResetValues returns each flag to its default")
Stub.equal(mode:Get(), "Legit", "ResetValues covers every flag")

-- Undo puts back what a reset, load or import replaced.
speed:Set(55)
window:ResetValues()
Stub.equal(speed:Get(), 40, "reset before undo")
Stub.check(window:Undo(), "Undo reports that it restored something")
Stub.equal(speed:Get(), 55, "Undo restores the values from before the reset")
Stub.check(not window:Undo(), "a second Undo has nothing to restore")

-- Share codes travel without files.
speed:Set(33)
tint:Set("ff0000")
local code = window:ExportConfig()
Stub.check(type(code) == "string" and string.sub(code, 1, 9) == "Halcyon1:", "ExportConfig gives a prefixed share code")
speed:Set(1)
tint:Set("000000")
local ok, message = window:ImportConfig("  " .. code .. "\n")
Stub.check(ok, "ImportConfig accepts a code with stray spaces: " .. tostring(message))
Stub.equal(speed:Get(), 33, "ImportConfig restores values")
Stub.equal(tint:Encode(), "ff0000", "ImportConfig restores colours")
Stub.check(window:Undo() and speed:Get() == 1, "an import can be undone")
local bad, why = window:ImportConfig("hello")
Stub.check(not bad and type(why) == "string", "a code without the prefix is refused with a reason")
bad, why = window:ImportConfig("Halcyon1:{not json")
Stub.check(not bad and type(why) == "string", "a broken code is refused with a reason")
window:Unload()

-- Per-game configs keep their own folder and autoload.
local perGame = Halcyon:CreateWindow({ Title = "Games", Folder = "GameHub", SavePreferences = false, Configs = { PerGame = "Place" } })
local walk = perGame:Tab({ Title = "Main" }):Slider({ Title = "Walk", Flag = "Walk", Min = 0, Max = 100 })
walk:Set(12)
Stub.check(perGame:SaveConfig("main"), "per-game config saved")
Stub.check(Stub.files["Halcyon/GameHub/configs/1/main.json"] ~= nil, "saved under the place id")
Stub.check(perGame:SetAutoload("main"), "per-game autoload set")
Stub.check(Stub.files["Halcyon/GameHub/configs/1/autoload.txt"] ~= nil, "autoload kept per game")
Stub.files["Halcyon/GameHub/configs/old.json"] = '{"version":1,"flags":{"Walk":77}}'
Stub.check(perGame:LoadConfig("old"), "a config saved before per-game folders still loads")
Stub.equal(walk:Get(), 77, "the shared config's values apply")
local listed = perGame:ListConfigs()
Stub.check(table.find(listed, "main") ~= nil and table.find(listed, "old") ~= nil, "the list shows this game's and shared configs")
perGame:Unload()

-- Callbacks that fail or take a while.
local hub = Halcyon:CreateWindow({ Title = "Calls", Folder = "CallHub", SavePreferences = false })
local page = hub:Tab({ Title = "Main" })
local broken = page:Toggle({ Title = "Broken", Callback = function()
	error("boom")
end })
local errors = 0
hub.ErrorsChanged:Connect(function()
	errors += 1
end)
broken:Set(true)
Stub.flush()
Stub.equal(#hub.Errors, 1, "a failing callback is recorded")
Stub.check(string.find(hub.Errors[1].Message, "boom", 1, true) ~= nil, "with its message")
Stub.equal(hub.Errors[1].Title, "Broken", "and the row it came from")
Stub.equal(errors, 1, "ErrorsChanged fires")
local line = Stub.byName(broken.Frame, "CallbackError")
Stub.check(line ~= nil and line.Visible, "the row shows the error under its title")
Stub.check(#Stub.warnings > 0, "the error is still printed for the console")

local slow = page:Button({ Title = "Slow", Callback = function()
	task.wait(1)
end })
slow:Press()
Stub.advance(0.3)
Stub.check(slow:IsLoading(), "a button whose callback yields shows its spinner")
Stub.advance(1)
Stub.check(not slow:IsLoading(), "the spinner stops when the callback returns")

local fixed = false
local flaky = page:Toggle({ Title = "Flaky", Callback = function(on)
	if not fixed then
		error("not yet")
	end
end })
flaky:Set(true)
Stub.flush()
fixed = true
flaky:Set(false)
Stub.flush()
local flakyLine = Stub.byName(flaky.Frame, "CallbackError")
Stub.check(flakyLine == nil or not flakyLine.Visible, "a later successful run clears the row's error")

local quiet = Halcyon:CreateWindow({ Title = "Quiet", Folder = "QuietCalls", SavePreferences = false, ShowErrors = false })
local mute = quiet:Tab({ Title = "Main" }):Toggle({ Title = "Mute", Callback = function()
	error("hidden")
end })
mute:Set(true)
Stub.flush()
Stub.equal(Stub.byName(mute.Frame, "CallbackError"), nil, "ShowErrors = false keeps errors off the rows")
Stub.equal(#quiet.Errors, 1, "but still records them")
quiet:Unload()
hub:Unload()

-- The config block copies and pastes share codes.
local shared = Halcyon:CreateWindow({ Title = "Share", Folder = "ShareHub", SavePreferences = false })
local shareTab = shared:Tab({ Title = "Settings" })
local level = shareTab:Slider({ Title = "Level", Flag = "Level", Min = 0, Max = 10, Default = 3 })
local block = shared:ConfigSection(shareTab)
Stub.flush()
local copyRow = Stub.byText(block.root, "Copy share code")
Stub.check(copyRow ~= nil, "the config block has a copy row")
Stub.click(copyRow)
Stub.check(type(Stub.clipboard) == "string" and string.sub(Stub.clipboard, 1, 9) == "Halcyon1:", "copying puts the code on the clipboard")
Stub.check(Stub.byText(block.root, "Paste share code") ~= nil, "and a paste row")
level:Set(9)
local imported = shared:ImportConfig(Stub.clipboard)
Stub.check(imported and level:Get() == 3, "the copied code restores the values")
shared:Unload()
