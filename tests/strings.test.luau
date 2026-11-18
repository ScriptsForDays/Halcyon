-- Built-in wording: translation packs, the hub's own replacements, and the
-- language a player picks in Settings.

-- English by default.
local plain = Halcyon:CreateWindow({ Title = "Words", Folder = "WordHub", SavePreferences = false })
local settings = plain:SettingsTab()
Stub.flush()
Stub.check(Stub.byText(settings.page, "Appearance") ~= nil, "English wording by default")
Stub.equal(Halcyon:GetLanguage(), "en", "the language starts as English")
plain:Unload()

-- A pack by code.
local spanish = Halcyon:CreateWindow({ Title = "Palabras", Folder = "WordHubEs", SavePreferences = false, Language = "es" })
local ajustes = spanish:SettingsTab()
Stub.flush()
Stub.equal(Halcyon:GetLanguage(), "es", "Language picks a pack")
Stub.check(Stub.byText(ajustes.page, "Appearance") == nil, "the pack replaces the English text")
Stub.check(Stub.byText(ajustes.page, "Apariencia") ~= nil, "with its own")
spanish:Unload()

-- Regional codes fall back to the base language, unknown ones to English.
Stub.equal(Halcyon:SetLanguage("es-mx"), "es", "es-mx uses the Spanish pack")
Stub.equal(Halcyon:SetLanguage("pt-pt"), "pt-br", "any Portuguese uses the Brazilian pack")
Stub.equal(Halcyon:SetLanguage("xx"), "en", "an unknown code falls back to English")
game:GetService("LocalizationService").RobloxLocaleId = "de-de"
Stub.equal(Halcyon:SetLanguage("auto"), "de", "auto follows the player's Roblox language")
Halcyon:SetLanguage("en")

-- The hub's own wording wins over any pack.
local custom = Halcyon:CreateWindow({
	Title = "Custom",
	Folder = "WordHubCustom",
	SavePreferences = false,
	Strings = { ["Unload the hub?"] = "Close everything?", ["Appearance"] = "Look" },
})
local customSettings = custom:SettingsTab()
Stub.flush()
Stub.check(Stub.byText(customSettings.page, "Look") ~= nil, "Strings replaces built-in text")
custom:RequestUnload()
Stub.flush()
Stub.check(Stub.byText(custom.gui, "Close everything?") ~= nil or Stub.find(game:GetService("Players").LocalPlayer.PlayerGui, function(instance)
	return instance.Text == "Close everything?"
end) ~= nil, "including dialog titles")
local listed = Halcyon:GetStrings()
Stub.equal(listed["Unload the hub?"], "Close everything?", "GetStrings shows the replacement for each key used")
custom:Unload()
Halcyon:SetStrings({ ["Unload the hub?"] = false, ["Appearance"] = false })

-- Placeholders in the text are filled in.
local counted = Halcyon:CreateWindow({ Title = "Counts", Folder = "WordHubCount", SavePreferences = false })
local slider = counted:Tab({ Title = "Farm" }):Slider({ Title = "Level", Flag = "Level", Min = 0, Max = 9 })
slider:Set(4)
local _, message = counted:ImportConfig(counted:ExportConfig())
Stub.equal(message, "Imported 1 settings.", "placeholders are filled in")
counted:Unload()

-- A language the player picks in Settings is used on the next run.
local picked = Halcyon:CreateWindow({ Title = "Pick", Folder = "WordHubPick" })
picked:SetLanguage("fr")
picked:Unload()
local again = Halcyon:CreateWindow({ Title = "Pick", Folder = "WordHubPick", Language = "en" })
Stub.equal(Halcyon:GetLanguage(), "fr", "the saved pick wins over the hub's Language")
again:Unload()
Halcyon:SetLanguage("en")
