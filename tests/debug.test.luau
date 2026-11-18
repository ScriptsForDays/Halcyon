-- Debug = true points at option names and looks Halcyon doesn't know, once
-- each, and stays quiet otherwise.

local function warningsWith(text)
	local count = 0
	for _, line in Stub.warnings do
		if string.find(line, text, 1, true) then
			count += 1
		end
	end
	return count
end

-- Off by default: a typo is ignored silently, as before.
local quiet = Halcyon:CreateWindow({ Title = "Quiet", Folder = "DebugQuiet", SavePreferences = false })
quiet:Tab({ Title = "Farm" }):Toggle({ Title = "Fly", Defualt = true })
Stub.flush()
Stub.equal(warningsWith("Defualt"), 0, "no debug warnings unless asked")
quiet:Unload()

local window = Halcyon:CreateWindow({ Title = "Debug", Folder = "DebugHub", SavePreferences = false, Debug = true, Sizee = Vector2.new(1, 1) })
Stub.flush()
Stub.equal(warningsWith('unknown option "Sizee", did you mean "Size"?'), 1, "a misspelt window option is named with a guess")

local tab = window:Tab({ Title = "Farm", Icno = "user" })
Stub.equal(warningsWith('Tab "Farm": unknown option "Icno"'), 1, "tabs are checked")
local section = tab:Section({ Title = "Main", Sid = "Right" })
Stub.equal(warningsWith('Section "Main": unknown option "Sid"'), 1, "sections are checked")

section:Toggle({ Title = "Fly", Defualt = true })
Stub.equal(warningsWith('Toggle "Fly": unknown option "Defualt", did you mean "Default"?'), 1, "elements are checked")
section:Toggle({ Title = "Fly", Defualt = true })
Stub.equal(warningsWith('unknown option "Defualt"'), 1, "each warning prints once")
section:Slider({ Title = "Speed", Min = 0, Max = 10, Default = 5, Suffix = " st", Flag = "Speed" })
Stub.equal(warningsWith('Slider "Speed"'), 0, "correct options raise nothing")
section:Toggle({ Title = "Glow", Style = "Glo" })
Stub.equal(warningsWith('Toggle look "Glo" doesn\'t exist; did you mean "Glow"?'), 1, "a misspelt look is named with a guess")
section:Toggle({ Title = "Made up", Teleport = true })
Stub.equal(warningsWith('unknown option "Teleport"; Halcyon ignores it.'), 1, "an invented option says it is ignored")
window:Notify({ Title = "Hi", Duraton = 3 })
Stub.equal(warningsWith('Notify "Hi": unknown option "Duraton"'), 1, "notices are checked")
Halcyon:SetTheme("Midnite")
Stub.equal(warningsWith('Theme "Midnite" does not exist'), 1, "an unknown theme is reported")
window:Unload()
Halcyon:SetDebug(false)
Halcyon:SetTheme("Midnight")
