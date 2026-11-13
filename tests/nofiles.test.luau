-- An executor, or Studio, with no file functions and no clipboard.
-- setup: writefile, readfile, isfile, isfolder, makefolder, delfile, listfiles, setclipboard = nil, nil, nil, nil, nil, nil, nil, nil

local Env, library = Halcyon.Internal.Env, Halcyon.Internal.library

Stub.check(not Env.canSave, "saving reported as unavailable")
local window = Halcyon:CreateWindow({ Title = "Plain Hub" })
local tab = window:Tab({ Title = "Movement" })
tab:Toggle({ Title = "Fly", Flag = "Fly" })

local ok, message = window:SaveConfig("main")
Stub.check(not ok and message == Env.NO_FILES, "saving a config says why it cannot")
ok, message = window:LoadConfig("main")
Stub.check(not ok and message == Env.NO_FILES, "loading a config says why it cannot")
Stub.equal(#window:ListConfigs(), 0, "no configs listed")

window:SetTabStyle("Top")
Stub.advance(1)
Stub.equal(next(Stub.files), nil, "nothing is written")
Stub.equal(library.toasts, nil, "no notice for a preference that cannot be saved")

local settings = window:SettingsTab()
Stub.check(Stub.byText(settings.page, "Saving is off") ~= nil, "the settings tab says saving is off")
Stub.check(Stub.byText(settings.page, "Config name") == nil, "config controls are left out")

local code = tab:Code({ Code = "print(1)" })
Stub.click(Stub.byName(code.Frame, "Copy"))
Stub.equal(library.toasts.active[1].options.Title, "Can't copy", "a failed copy is reported")

local access
task.spawn(function()
	access = Halcyon:Authenticate({ Keys = { "abc" } })
end)
local card
for _, gui in Stub.guis() do
	card = card or Stub.byName(gui, "Dialog")
end
Stub.click(Stub.byText(card, "Get a key"))
Stub.byName(card, "Key").Text = "abc"
Stub.click(Stub.byText(card, "Verify key"))
Stub.check(type(access) == "table" and access.Saved == false, "a key is accepted but not reported as saved")

Halcyon:Unload()
Stub.equal(#Stub.guis(), 0, "everything removed")
