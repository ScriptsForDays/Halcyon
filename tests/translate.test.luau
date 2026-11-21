-- Translate: a hub's own text shown in the player's language, from a
-- translation service, saved per language. Values, flags and search keep
-- working, numbers survive, and a failing service leaves the text as written.

local calls = {}
local function service(lines, from, to)
	table.insert(calls, { lines = table.clone(lines), from = from, to = to })
	local out = {}
	for index, line in lines do
		out[index] = "[" .. to .. "] " .. line
	end
	return out
end

local function shows(root, text)
	return Stub.find(root, function(instance)
		return (instance:IsA("TextLabel") or instance:IsA("TextButton")) and instance.Text == text
	end) ~= nil
end

local window = Halcyon:CreateWindow({
	Title = "Orchard",
	Folder = "TranslateHub",
	SavePreferences = false,
	Language = "de",
	Translate = {
		Service = service,
		Fixes = { de = { ["Auto sell"] = "Automatisch verkaufen" } },
		Skip = { "Coins" },
	},
})
local tab = window:Tab({ Title = "Farm", Group = "Farming" })
window:Tab({ Title = "Dashboard" })
local section = tab:Section({ Title = "Auto" })
section:Stat({ Title = "Ping", Value = 40 })
section:Stat({ Title = "FPS", Value = 60 })
local farm = section:Toggle({ Title = "Auto farm", Description = "Collects every few seconds", Flag = "AutoFarm" })
local sell = section:Toggle({ Title = "Auto sell" })
local zone = section:Dropdown({ Title = "Zone", Values = { "Forest", "Desert" }, Default = "Forest", Flag = "Zone" })
section:Input({ Title = "Target", Placeholder = "Player name" })
section:Paragraph({ Title = "Coins", Content = "Gold you carry" })
section:Label({ Title = "Orchard keeps your Coins safe" })
section:Input({ Title = "Share code", Placeholder = "Orchard1:..." })
Stub.flush()
Stub.advance(1)

Stub.check(shows(window.root, "[de] Auto farm"), "a row's title shows in the player's language")
Stub.check(shows(window.root, "[de] Collects every few seconds"), "and its description")
Stub.check(shows(window.root, "[de] Auto"), "and the section's header")
Stub.check(shows(window.root, "[de] Farm"), "and the tab's name")
Stub.check(shows(window.root, "[de] Orchard keeps your Coins safe"), "the hub's name and Skip words inside a line come back as written")
local named = false
for _, call in calls do
	for _, line in call.lines do
		if string.find(line, "keeps your", 1, true) and (string.find(line, "Orchard", 1, true) or string.find(line, "Coins", 1, true)) then
			named = true
		end
	end
end
Stub.check(not named, "and are not sent to the service")
Stub.check(Stub.find(window.root, function(instance)
	return instance:IsA("TextBox") and instance.PlaceholderText == "Orchard1:..."
end) ~= nil, "a code-like word stays as written")
Stub.check(shows(window.root, "[de] Forest"), "the picked option shows translated")
Stub.check(Stub.find(window.root, function(instance)
	return instance:IsA("TextBox") and instance.PlaceholderText == "[de] Player name"
end) ~= nil, "and a placeholder")
Stub.check(shows(window.root, "Automatisch verkaufen"), "a fix replaces the service's wording")
Stub.check(shows(window.root, "Coins") and not shows(window.root, "[de] Coins"), "Skip leaves a word as written")
Stub.equal(zone:Get(), "Forest", "values stay as written")
Stub.check(shows(window.root, "[de] Farming"), "sidebar group names are translated")
Stub.check(shows(window.root, "Übersicht"), "common hub words use set translations")
local jargon = false
for _, call in calls do
	for _, line in call.lines do
		if line == "Ping" or line == "FPS" or line == "Dashboard" then
			jargon = true
		end
	end
end
Stub.check(not jargon and shows(window.root, "Ping") and shows(window.root, "FPS"), "gaming jargon and acronyms stay as written, unsent")
Stub.equal(window.Flags.AutoFarm, farm, "flags are untouched")
Stub.check(#calls >= 1 and calls[1].from == "en" and calls[1].to == "de", "the service is asked from English to German")
Stub.check(#calls <= 2, "lines go to the service in batches, not one by one")

-- Halcyon's own words are already German; they never go to the service.
window:SettingsTab()
Stub.flush()
Stub.advance(1)
local builtIn = false
for _, call in calls do
	for _, line in call.lines do
		if line == "Einstellungen" or line == "Settings" then
			builtIn = true
		end
	end
end
Stub.check(not builtIn, "built-in words are not sent to the service")
local ownParts = false
for _, call in calls do
	for _, line in call.lines do
		if line == "English" or line == "Español" or line == "accent" or line == "Português (Brasil)" then
			ownParts = true
		end
	end
end
Stub.check(not ownParts, "the Settings tab's own options, such as language names, are not sent")

-- Text set later is translated too, and numbers come back as they were.
farm:SetTitle("Auto farm all zones")
window:Notify({ Title = "Farming", Content = "123 coins so far", Duration = 0 })
Stub.flush()
Stub.advance(1)
Stub.check(shows(window.root, "[de] Auto farm all zones"), "SetTitle text is translated")
local sent = false
for _, call in calls do
	for _, line in call.lines do
		if string.find(line, "coins so far", 1, true) and not string.find(line, "123", 1, true) then
			sent = true
		end
	end
end
Stub.check(sent, "numbers are swapped for markers before the text is sent")
Stub.check(shows(window.library.overlay.gui, "[de] 123 coins so far"), "and put back in the translation")

-- Search finds rows by their translated words as well.
window:Search("automatisch")
Stub.flush()
Stub.check(sell.Frame.Visible and not farm.Frame.Visible, "search matches the translated title")
window:Search("")
Stub.flush()

-- Results are saved per language, so the next run asks for nothing new.
Stub.advance(3)
Stub.check(Stub.files["Halcyon/TranslateHub/translations/en-de.json"] ~= nil, "translations are saved in the workspace")
window:Unload()
table.clear(calls)
local again = Halcyon:CreateWindow({ Title = "Farm", Folder = "TranslateHub", SavePreferences = false, Language = "de", Translate = { Service = service } })
again:Tab({ Title = "Farm" }):Section({ Title = "Auto" }):Toggle({ Title = "Auto farm" })
Stub.flush()
Stub.advance(1)
Stub.check(shows(again.root, "[de] Auto farm"), "a saved translation shows on the next run")
Stub.equal(#calls, 0, "without asking the service again")

-- Switching language translates the hub's text again, live.
again:SetLanguage("fr")
Stub.flush()
Stub.advance(1)
Stub.check(shows(again.root, "[fr] Auto farm"), "switching language translates again")
again:SetLanguage("en")
Stub.flush()
Stub.check(shows(again.root, "Auto farm"), "and English shows the text as written")
again:Unload()

-- A hub written in another language translates into English too.
table.clear(calls)
local russian = Halcyon:CreateWindow({ Title = "Ферма", Folder = "TranslateRussian", SavePreferences = false, Language = "en", Translate = { From = "ru", Service = service } })
russian:Tab({ Title = "Ферма" }):Toggle({ Title = "Автосбор монет" })
Stub.flush()
Stub.advance(1)
Stub.check(shows(russian.root, "[en] Автосбор монет") and calls[1] and calls[1].from == "ru", "a hub written in Russian is translated from Russian")
russian:Unload()

-- English needs no service; a failing service leaves the text as written.
table.clear(calls)
local english = Halcyon:CreateWindow({ Title = "Farm", Folder = "TranslateEnglish", SavePreferences = false, Language = "en", Translate = { Service = service } })
english:Tab({ Title = "Farm" }):Toggle({ Title = "Auto farm" })
Stub.flush()
Stub.advance(1)
Stub.equal(#calls, 0, "a hub already in the player's language asks for nothing")
english:Unload()

local failures = 0
local broken = Halcyon:CreateWindow({
	Title = "Farm",
	Folder = "TranslateBroken",
	SavePreferences = false,
	Language = "fr",
	Translate = {
		Service = function()
			failures += 1
			error("service down")
		end,
	},
})
broken:Tab({ Title = "Farm" }):Toggle({ Title = "Auto farm" })
Stub.flush()
Stub.advance(60)
Stub.check(shows(broken.root, "Auto farm"), "a failing service leaves the text as written")
Stub.check(failures >= 1 and failures <= 3, "and is given up on after a few tries")
broken:Unload()
